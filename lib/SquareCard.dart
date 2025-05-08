import 'package:cw/Data/Task.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SquareCard extends StatelessWidget {
  final Task task;
  const SquareCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMMM d, yyyy');
    final String formattedDate = formatter.format(task.date);
    
    // Get theme colors
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyMedium!.color ?? Colors.black;
    final secondaryTextColor = theme.disabledColor;
    final backgroundColor = theme.scaffoldBackgroundColor;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: 200, // Fixed width for a square card
        height: 200, // Fixed height for a square card
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,  // Use theme card color
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.6),
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
                      color: primaryColor, // Fill color for the box from theme
                      borderRadius: BorderRadius.circular(8), // Optional: Rounded corners
                    ),
                    child: const Center(
                      child: Text(
                        '🧹',
                        style: TextStyle(fontSize: 20), // Emoji size
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    task.category,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,  // Use theme text color
                    ),
                  ),
                ],
              ),
            ),
            // Middle text (task name)
            Text(
              task.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor, // Use theme text color
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
                  color: secondaryTextColor, // Use theme disabled color
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
