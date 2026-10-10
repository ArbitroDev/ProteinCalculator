import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The shaker of the logo as an icon, upright, for the today tab: Lucide
/// has none. Sized and colored by the surrounding [IconTheme], like [Icon].
class ShakerIcon extends StatelessWidget {
  const ShakerIcon({super.key});

  /// The logo shaker (viewBox 0 0 100 100) scaled by 0.3 into the 24 x 24
  /// grid of Lucide, with its stroke width: lid, cap and handle, then the
  /// body with a wave of liquid.
  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      // A little wider than the logo, to weigh as much as the other icons.
      '<g transform="translate(12 0) scale(1.2 1) translate(-12 0)">'
      '<rect x="7.2" y="6.9" width="9.6" height="3" rx="0.75"/>'
      '<path d="M7.8 6.9 Q7.8 4.5 9.9 4.5 H14.1 Q16.2 4.5 16.2 6.9 Z"/>'
      '<rect x="8.7" y="2.7" width="2.7" height="2.1" rx="0.6"/>'
      '<g fill="none" stroke="#000" stroke-linecap="round" '
      'stroke-linejoin="round">'
      '<path d="M13.5 4.8 V3 Q13.5 1.5 14.85 1.5 Q16.2 1.5 16.2 3 V4.8" '
      'stroke-width="1.5"/>'
      '<path d="M8.1 9.9 L8.85 21.3 Q9 22.8 10.5 22.8 H13.5 Q15 22.8 15.15 '
      '21.3 L15.9 9.9" stroke-width="2"/>'
      '<path d="M9.3 16 Q10.65 15.1 12 16 T14.7 16" stroke-width="1.7"/>'
      '</g></g></svg>';

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return SvgPicture.string(
      _svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        theme.color ?? const Color(0xFF000000),
        BlendMode.srcIn,
      ),
      excludeFromSemantics: true,
    );
  }
}
