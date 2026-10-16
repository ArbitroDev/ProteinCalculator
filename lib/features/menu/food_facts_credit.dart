import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/theme.dart';

/// Address of Open Food Facts, where the values of the products scanned
/// come from.
const foodFactsAddress = 'world.openfoodfacts.org';

/// Card crediting Open Food Facts, as its license asks of the apps using its
/// data. Not a link: its website takes donations, which Google Play reviews
/// may take for a payment outside its billing.
class FoodFactsCredit extends StatelessWidget {
  const FoodFactsCredit({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(LucideIcons.scanBarcode, size: 30, color: colors.scan),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Open Food Facts',
                    style: textTheme.bodyLarge!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(foodFactsAddress, style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
