import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Address of Open Food Facts, where the values of the products scanned
/// come from.
const foodFactsUrl = 'https://world.openfoodfacts.org';

/// Card opening Open Food Facts in the browser, as its license asks of the
/// apps using its data.
class FoodFactsLink extends StatelessWidget {
  const FoodFactsLink({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      link: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => launchUrl(
            Uri.parse(foodFactsUrl),
            mode: LaunchMode.externalApplication,
          ),
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
                      Text(
                        foodFactsUrl.replaceFirst('https://', ''),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.externalLink,
                  size: 20,
                  color: colors.accentText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
