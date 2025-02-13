import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  String id;
  String category;
  String name;
  DateTime date;
  bool done;
  int points;

  Task(
      {required this.id,
      required this.category,
      required this.name,
      required this.date,
      this.done = false,
      this.points = 1});

  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Task(
      id: doc.id,
      category: data['category'] ?? '',
      name: data['name'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      done: data['done'] ?? false,
      points: data['points'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'name': name,
      'date': date,
      'done': done,
      'points': points,
    };
  }
}
