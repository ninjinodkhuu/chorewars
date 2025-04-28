import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final String? description;
  final int points;
  final String householdId;
  final String assignedTo;
  final String createdBy;
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.points,
    required this.householdId,
    required this.assignedTo,
    required this.createdBy,
    this.isCompleted = false,
    this.dueDate,
    required this.createdAt,
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      points: data['points'] ?? 0,
      householdId: data['householdId'] ?? '',
      assignedTo: data['assignedTo'] ?? '',
      createdBy: data['createdBy'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      dueDate: data['dueDate']?.toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'points': points,
      'householdId': householdId,
      'assignedTo': assignedTo,
      'createdBy': createdBy,
      'isCompleted': isCompleted,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}