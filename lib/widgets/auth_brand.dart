import 'package:flutter/material.dart';

import '../themes/app_theme.dart';

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.graphic_eq, color: AppTheme.accent, size: 36),
      ),
      const SizedBox(height: 12),
      Text(
        'MUSICO',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          letterSpacing: 4,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}
