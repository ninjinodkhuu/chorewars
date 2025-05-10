import 'package:flutter/material.dart';

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final double value;
  final bool isSelected;

  const _Badge(this.text, this.color, this.value, this.isSelected);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? color : color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSelected ? 12 : 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: isSelected ? 10 : 8,
            ),
          ),
        ],
      ),
    );
  }
}
