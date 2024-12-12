import 'package:flutter/material.dart';

class SquareCard2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: 200, // Fixed width for a square card
        height: 200, // Fixed height for a square card
        decoration: BoxDecoration(
          color: Colors.blue[400],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 4,
              offset: Offset(0, 2), // Shadow position
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
                  SizedBox(width: 15),
                  Container(
                    width: 40, // Fixed width for the square box
                    height: 40, // Fixed height for the square box
                    decoration: BoxDecoration(
                      color: Colors.blue[600], // Fill color for the box
                      borderRadius: BorderRadius.circular(8), // Optional: Rounded corners
                    ),
                    child: Center(
                      child: Text(
                        '🧹',
                        style: TextStyle(fontSize: 20), // Emoji size
                      ),
                    ),
                  ),

                  SizedBox(width: 8),
                  Text(
                    'Clean House',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Middle text
            Text(
              'Clean Bathroom',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[100],
              ),
              textAlign: TextAlign.left,
            ),
            // Bottom date
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'December 11th, 2024',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[300],
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
