import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Address of the public source code repository.
const sourceCodeUrl = 'https://github.com/ArbitroDev/ProteinCalculator';

/// GitHub mark, from GitHub's Octicons (MIT license).
const _githubMark =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="'
    'M10.226 17.284c-2.965-.36-5.054-2.493-5.054-5.256 0-1.123.404-2.336 '
    '1.078-3.144-.292-.741-.247-2.314.09-2.965.898-.112 2.111.36 2.83 1.01'
    '.853-.269 1.752-.404 2.853-.404 1.1 0 1.999.135 2.807.382.696-.629 '
    '1.932-1.1 2.83-.988.315.606.36 2.179.067 2.942.72.854 1.101 2 1.101 '
    '3.167 0 2.763-2.089 4.852-5.098 5.234.763.494 1.28 1.572 1.28 2.807'
    'v2.336c0 .674.561 1.056 1.235.786 4.066-1.55 7.255-5.615 7.255-10.646'
    'C23.5 6.188 18.334 1 11.978 1 5.62 1 .5 6.188.5 12.545c0 4.986 3.167 '
    '9.12 7.435 10.669.606.225 1.19-.18 1.19-.786V20.63a2.9 2.9 0 0 1-1.078'
    '.224c-1.483 0-2.359-.808-2.987-2.313-.247-.607-.517-.966-1.034-1.033'
    '-.27-.023-.359-.135-.359-.27 0-.27.45-.471.898-.471.652 0 1.213.404 '
    '1.797 1.235.45.651.921.943 1.483.943.561 0 .92-.202 1.437-.719.382-'
    '.381.674-.718.944-.943"/></svg>';

/// Card opening the source code repository in the browser.
class GitHubLink extends StatelessWidget {
  const GitHubLink({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            Uri.parse(sourceCodeUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SvgPicture.string(
                  _githubMark,
                  width: 32,
                  height: 32,
                  colorFilter: ColorFilter.mode(colors.text, BlendMode.srcIn),
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.aboutGitHub,
                        style: textTheme.bodyLarge!.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sourceCodeUrl.replaceFirst('https://', ''),
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
