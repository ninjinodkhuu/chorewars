import 'package:chore/Data/Task.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SquareCard extends StatelessWidget {
  final Task task;
  const SquareCard({super.key, required this.task});
  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMMM d, yyyy');
    final String formattedDate = formatter.format(task.date);
    final bool isAbandoned = task.status == 'abandoned';
    final Color cardColor = isAbandoned ? Colors.grey[400]! : Colors.blue[900]!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: 200, // Fixed width for a square card
        height: 200, // Fixed height for a square card
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 4,
              offset: const Offset(0, 2), // Shadow position
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title with emoji at the top
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 15),
                  Container(
                    width: 40, // Fixed width for the square box
                    height: 40, // Fixed height for the square box
                    decoration: BoxDecoration(
                      color: isAbandoned
                          ? Colors.grey[500]
                          : Colors.blue[600], // Fill color for the box
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        '🧹',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    task.category,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isAbandoned ? Colors.grey[300] : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Middle text
            Text(
              task.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isAbandoned ? Colors.grey[300] : Colors.white,
              ),
              textAlign: TextAlign.left,
            ),
            // Bottom date
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: isAbandoned ? Colors.grey[400] : Colors.grey[300],
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
