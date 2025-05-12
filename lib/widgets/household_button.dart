import 'package:flutter/material.dart';
import '../services/household_service.dart';

class HouseholdButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isSelected;

  const HouseholdButton({
    super.key,
    required this.onPressed,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: HouseholdService.hasPendingInvites(),
      builder: (context, snapshot) {
        bool hasPendingInvites = snapshot.data ?? false;

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[100] : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.home,
                  color: isSelected ? Colors.blue[900] : Colors.grey[700],
                  size: 30,
                ),
                onPressed: onPressed,
              ),
            ),
            if (hasPendingInvites)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
