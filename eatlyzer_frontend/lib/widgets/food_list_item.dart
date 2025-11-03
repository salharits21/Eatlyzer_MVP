// === lib/widgets/food_list_item.dart ===

import 'package:flutter/material.dart';
import 'package:eatlyzer_frontend/main.dart';

class FoodListItem extends StatelessWidget {
  final String foodName;
  final String calories;
  final String time;
  final IconData icon;

  const FoodListItem({
    super.key,
    required this.foodName,
    required this.calories,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[100],
            child: Icon(icon, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foodName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  time,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            calories,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MyApp.primaryColor),
          ),
        ],
      ),
    );
  }
}