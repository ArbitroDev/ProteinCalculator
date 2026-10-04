import 'package:flutter/material.dart';
import 'package:protein_calculator/core/theme.dart';

/// Centered message of a list that has nothing to show yet.
class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge!
            .copyWith(color: AppColors.of(context).textSecondary),
      ),
    ),
  );
}
