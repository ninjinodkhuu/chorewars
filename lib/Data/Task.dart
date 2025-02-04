import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  String id;
  String category;
  String name;
  DateTime date;
  bool done;

  Task(
      {required this.id,
      required this.category,
      required this.name,
      required this.date,
      this.done = false});

  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Task(
      id: doc.id,
      category: data['category'] ?? '',
      name: data['name'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      done: data['done'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'name': name,
      'date': date,
      'done': done,
    };
  }
}
