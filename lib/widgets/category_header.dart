import 'package:flutter/material.dart';

class CategoryHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAllPressed;

  const CategoryHeader({
    Key? key,
    required this.title,
    this.onSeeAllPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onSeeAllPressed != null)
          TextButton(
            onPressed: onSeeAllPressed,
            child: const Text(
              'See All',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}