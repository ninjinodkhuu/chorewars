const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Helper function to handle errors
const handleError = (error, context) => {
  console.error('Error:', error);
  console.error('Context:', context);
  throw new functions.https.HttpsError('internal', error.message);
};

// Helper to get user's household
async function getUserHousehold(userId) {
  const userDoc = await admin.firestore().doc(`users/${userId}`).get();
  if (!userDoc.exists) throw new Error('User not found');
  return userDoc.get('householdID');
}

// 1) Broadcast task creations/updates:
exports.broadcastTaskUpdate = functions.firestore
    .document('household/{householdID}/members/{memberID}/tasks/{taskID}')
    .onWrite(async (change, context) => {
        try {
            const { householdID, memberID, taskID } = context.params;
            const before = change.before.exists ? change.before.data() : null;
            const after = change.after.exists ? change.after.data() : null;
            
            // Determine action
            let action = '';
            let taskName = after ? after.name : (before ? before.name : 'unknown');
            
            if (!change.before.exists) {
                action = 'added';
            } else if (!change.after.exists) {
                action = 'removed';
            } else if (!before.done && after.done) {
                action = 'completed';
            } else {
                action = 'updated';
            }

            // Get user info for more detailed notification
            const memberDoc = await admin.firestore()
                .doc(`household/${householdID}/members/${memberID}`)
                .get();
            const memberEmail = memberDoc.exists ? memberDoc.data().email : 'A member';
            
            // Craft notification
            const payload = {
                notification: {
                    title: `Task ${action}`,
                    body: `${memberEmail} ${action} the task "${taskName}"`,
                },
                data: {
                    taskId: taskID,
                    householdId: householdID,
                    memberId: memberID,
                    action: action
                }
            };

            // Send to household topic
            return admin.messaging().sendToTopic(householdID, payload);
        } catch (error) {
            handleError(error, context);
        }
    });

// 2) Broadcast new expenses:
exports.broadcastExpense = functions.firestore
    .document('users/{uid}/expenses/{expId}')
    .onCreate(async (snap, context) => {
        try {
            const { category, amount, description } = snap.data();
            const { uid, expId } = context.params;

            // Get user and household info
            const userDoc = await admin.firestore().doc(`users/${uid}`).get();
            if (!userDoc.exists) {
                throw new Error('User document not found');
            }

            const userData = userDoc.data();
            const householdID = userData.householdID;
            const userEmail = userData.email || 'A member';

            if (!householdID) {
                throw new Error('User has no associated household');
            }

            // Craft notification
            const payload = {
                notification: {
                    title: 'New Expense Added',
                    body: `${userEmail} added $${amount.toFixed(2)} for ${category}${description ? ': ' + description : ''}`,
                },
                data: {
                    expenseId: expId,
                    householdId: householdID,
                    category: category,
                    amount: amount.toString()
                }
            };

            // Send to household topic
            return admin.messaging().sendToTopic(householdID, payload);
        } catch (error) {
            handleError(error, context);
        }
    });

// 3) Update household statistics when task is completed
exports.updateHouseholdStats = functions.firestore
    .document('household/{householdID}/members/{memberID}/tasks/{taskID}')
    .onUpdate(async (change, context) => {
        try {
            const before = change.before.data();
            const after = change.after.data();
            const { householdID, memberID } = context.params;

            // Only proceed if task was just completed
            if (!before.done && after.done) {
                const householdRef = admin.firestore().doc(`household/${householdID}`);
                const memberRef = householdRef.collection('members').doc(memberID);

                await admin.firestore().runTransaction(async (transaction) => {
                    const householdDoc = await transaction.get(householdRef);
                    const memberDoc = await transaction.get(memberRef);

                    if (!householdDoc.exists || !memberDoc.exists) {
                        throw new Error('Required documents do not exist');
                    }

                    // Update member stats
                    const memberData = memberDoc.data();
                    const tasksCompleted = (memberData.tasksCompleted || 0) + 1;
                    const points = (memberData.points || 0) + (after.points || 0);

                    transaction.update(memberRef, {
                        tasksCompleted,
                        points,
                        lastTaskCompleted: admin.firestore.FieldValue.serverTimestamp()
                    });

                    // Update household stats
                    const householdData = householdDoc.data();
                    transaction.update(householdRef, {
                        totalTasksCompleted: (householdData.totalTasksCompleted || 0) + 1,
                        totalPoints: (householdData.totalPoints || 0) + (after.points || 0)
                    });
                });
            }
            return null;
        } catch (error) {
            handleError(error, context);
        }
    });

// Update category totals when expense is added/updated
exports.updateCategoryTotals = functions.firestore
    .document('users/{userId}/expenses/{expenseId}')
    .onWrite(async (change, context) => {
        try {
            const { userId } = context.params;
            const beforeData = change.before.exists ? change.before.data() : null;
            const afterData = change.after.exists ? change.after.data() : null;

            // Calculate amount changes
            let amountDiff = 0;
            if (afterData && !beforeData) {
                // New expense
                amountDiff = afterData.amount;
            } else if (!afterData && beforeData) {
                // Deleted expense
                amountDiff = -beforeData.amount;
            } else if (afterData && beforeData) {
                // Updated expense
                amountDiff = afterData.amount - beforeData.amount;
            }

            if (amountDiff === 0) return null;

            const householdID = await getUserHousehold(userId);
            const categoryRef = admin.firestore()
                .collection('households')
                .doc(householdID)
                .collection('categories')
                .doc(afterData?.categoryId || beforeData?.categoryId);

            await admin.firestore().runTransaction(async (transaction) => {
                const categoryDoc = await transaction.get(categoryRef);
                if (!categoryDoc.exists) {
                    throw new Error('Category not found');
                }

                const currentTotal = categoryDoc.data().totalExpenses || 0;
                const monthKey = new Date().toISOString().slice(0, 7); // YYYY-MM format

                const monthlyTotals = categoryDoc.data().monthlyTotals || {};
                monthlyTotals[monthKey] = (monthlyTotals[monthKey] || 0) + amountDiff;

                transaction.update(categoryRef, {
                    totalExpenses: currentTotal + amountDiff,
                    monthlyTotals,
                    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                });
            });
        } catch (error) {
            handleError(error, context);
        }
    });

// Notify household members of large expenses
exports.notifyLargeExpense = functions.firestore
    .document('users/{userId}/expenses/{expenseId}')
    .onCreate(async (snap, context) => {
        try {
            const expense = snap.data();
            const { userId } = context.params;
            const householdID = await getUserHousehold(userId);

            // Configure threshold as needed
            const LARGE_EXPENSE_THRESHOLD = 1000; // $10.00 (stored in cents)

            if (expense.amount >= LARGE_EXPENSE_THRESHOLD) {
                const userDoc = await admin.firestore()
                    .collection('users')
                    .doc(userId)
                    .get();
                
                const userName = userDoc.data().displayName || 'A household member';
                const amountFormatted = (expense.amount / 100).toFixed(2);

                const payload = {
                    notification: {
                        title: 'Large Expense Alert',
                        body: `${userName} added an expense of $${amountFormatted} for ${expense.categoryName}`,
                    },
                    data: {
                        expenseId: context.params.expenseId,
                        amount: expense.amount.toString(),
                        categoryId: expense.categoryId,
                        type: 'large_expense',
                    }
                };

                await admin.messaging().sendToTopic(householdID, payload);
            }
        } catch (error) {
            handleError(error, context);
        }
    });

// Generate monthly expense report
exports.generateMonthlyReport = functions.pubsub
    .schedule('0 0 1 * *') // Run at midnight on the first of each month
    .timeZone('America/New_York')
    .onRun(async (context) => {
        try {
            const households = await admin.firestore()
                .collection('households')
                .get();

            for (const household of households.docs) {
                const householdId = household.id;
                const previousMonth = new Date();
                previousMonth.setMonth(previousMonth.getMonth() - 1);
                const monthKey = previousMonth.toISOString().slice(0, 7);

                // Aggregate all member expenses
                const members = await household.ref.collection('members').get();
                let totalExpenses = 0;
                const categoryTotals = {};

                for (const member of members.docs) {
                    const expenses = await member.ref
                        .collection('expenses')
                        .where('date', '>=', new Date(monthKey + '-01'))
                        .where('date', '<', new Date(previousMonth.getFullYear(), previousMonth.getMonth() + 1, 1))
                        .get();

                    for (const expense of expenses.docs) {
                        const expenseData = expense.data();
                        totalExpenses += expenseData.amount;
                        categoryTotals[expenseData.categoryId] = (categoryTotals[expenseData.categoryId] || 0) + expenseData.amount;
                    }
                }

                // Store monthly report
                await household.ref.collection('reports').doc(monthKey).set({
                    totalExpenses,
                    categoryTotals,
                    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    month: monthKey,
                });

                // Notify household members
                const totalFormatted = (totalExpenses / 100).toFixed(2);
                await admin.messaging().sendToTopic(householdId, {
                    notification: {
                        title: 'Monthly Expense Report',
                        body: `Your household spent $${totalFormatted} last month`,
                    },
                    data: {
                        type: 'monthly_report',
                        month: monthKey,
                        total: totalExpenses.toString(),
                    }
                });
            }
        } catch (error) {
            handleError(error, context);
        }
    });