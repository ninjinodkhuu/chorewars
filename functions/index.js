const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();

// 1) Broadcast task creations/updates:
exports.broadcastTaskUpdate = functions.firestore
  .document('household/{householdID}/members/{memberID}/tasks/{taskID}')
  .onWrite(async (change, context) => {
    // Determine action
    const before = change.before.data();
    const after  = change.after.data();
    let action = '';
    if (!change.befire.exists) {
      action = 'added';
    } else if (!change.after.exists) {
      action = 'removed';
    } else if (!before.done && after.done) {
      action = 'completed';
    } else {
      action = 'updated';
    }
    
    // craft notification
    const payload     = {
      notification: {
        title: `Task ${action}`,
        body: `A task was ${action} in your household.`,
      }
    };
    return admin.messaging().sendToTopic(householdID, payload);
  });

// 2) Broadcast new expenses:
exports.broadcastExpense = functions.firestore
  .document('users/{uid}/expenses/{expId}')
  .onCreate(async (snap, context) => {
    const { category, amount } = snap.data();
    const uid        = context.params.uid;
    const userDoc    = await admin.firestore().doc(`users/${uid}`).get();
    const householdID = userDoc.get('householdID');
    const payload    = {
      notification: {
        title: 'New Expense',
        body: `$${amount.toFixed(2)} spent on ${category}.`,
      }
    };
    return admin.messaging().sendToTopic(householdID, payload);
  });
