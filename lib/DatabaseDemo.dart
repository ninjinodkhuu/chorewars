import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseDemo extends StatefulWidget {
  const DatabaseDemo({super.key});

  @override
  _DatabaseDemoState createState() => _DatabaseDemoState();
}

class _DatabaseDemoState extends State<DatabaseDemo> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskController = TextEditingController();

  Future<void> saveData(String task) async {
    try {
      await _firestore.collection('tasks').add({
        'taskName': task,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task Saved!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<List<Map<String, dynamic>>> retrieveDataOnce() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('tasks').orderBy('timestamp').get();
      return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print("Error getting data: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Database Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _taskController,
              decoration: const InputDecoration(
                labelText: 'Enter Task',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                if (_taskController.text.isNotEmpty) {
                  saveData(_taskController.text);
                  _taskController.clear();
                }
              },
              child: const Text('Save Task'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() {}); // Triggers a rebuild which refetches data
              },
              child: const Text('Retrieve Data'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: retrieveDataOnce(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error.toString()}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No tasks found.'));
                  }
                  final tasks = snapshot.data!;
                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(tasks[index]['taskName']),
                        subtitle: Text(
                            tasks[index]['timestamp']?.toDate().toString() ?? 'No timestamp'
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}