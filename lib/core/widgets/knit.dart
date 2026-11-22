import 'dart:math';

import 'package:flutter/material.dart';
import 'package:protein_calculator/core/theme.dart';

/// Side of a stitch of the knitted tab bar of the Christmas theme.
const knitCell = 2.0;

const _white = Color(0xFFFFFFFF);

/// Darker wool under a colored stitch, so the blue does not show between
/// its two legs.
const _whiteWool = Color(0xFFBFC9F5);
const _redWool = Color(0xFFA3172B);

/// Icons of the tab bar knitted stitch by stitch, `#` for a stitch, 17 by
/// 17: the Lucide icons of the tabs (and the shaker of the today tab) traced
/// with lines one stitch wide, centered by their weight rather than their
/// edges: the shaker, heavy at the top, sits a stitch lower, and the basket,
/// heavy at the bottom, a stitch higher.
abstract final class KnitMotifs {
  static const today = [
    '.................',
    '..........###....',
    '....###..#...#...',
    '....###..#...#...',
    '....#########....',
    '...#.........#...',
    '..#############..',
    '..#.#.#.#.#.#.#..',
    '..#############..',
    '...#.........#...',
    '...#.........#...',
    '....#.##....#....',
    '....##..#..##....',
    '....#....##.#....',
    '....#.......#....',
    '.....#.....#.....',
    '......#####......',
  ];

  static const products = [
    '.................',
    '......#...#......',
    '.....#.....#.....',
    '....#.......#....',
    '...#.........#...',
    '..#...........#..',
    '.###############.',
    '..#...#...#...#..',
    '..#...#...#...#..',
    '..#...#...#...#..',
    '...###########...',
    '...#..#...#..#...',
    '...#..#...#..#...',
    '....#########....',
    '.................',
    '.................',
    '.................',
  ];

  static const history = [
    '.................',
    '.#....#####......',
    '.#..##.....##....',
    '.#.#.........#...',
    '.##...........#..',
    '.#......#.....#..',
    '.#####..#......#.',
    '........#......#.',
    '.#......#......#.',
    '.#.......#.....#.',
    '.#........##...#.',
    '..#...........#..',
    '..#...........#..',
    '...#.........#...',
    '....##.....##....',
    '......#####......',
    '.................',
  ];

  static const stats = [
    '.................',
    '.#...............',
    '.#...............',
    '.#.......#.......',
    '.#.......#.......',
    '.#.......#.......',
    '.#.......#..#....',
    '.#.......#..#....',
    '.#.......#..#....',
    '.#.......#..#....',
    '.#...#...#..#....',
    '.#...#...#..#....',
    '.#...#...#..#....',
    '.#...............',
    '..#..............',
    '...#############.',
    '.................',
  ];

  static const menu = [
    '.................',
    '.................',
    '.................',
    '.................',
    '..#############..',
    '.................',
    '.................',
    '.................',
    '..#############..',
    '.................',
    '.................',
    '.................',
    '..#############..',
    '.................',
    '.................',
    '.................',
    '.................',
  ];

  static const plus = [
    '.................',
    '.................',
    '.................',
    '........#........',
    '........#........',
    '........#........',
    '........#........',
    '........#........',
    '...###########...',
    '........#........',
    '........#........',
    '........#........',
    '........#........',
    '........#........',
    '.................',
    '.................',
    '.................',
  ];
}

/// Two legs of a stitch, as a V, in a cell at the origin.
final Path _stitch = () {
  Path leg(double x, double angle) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: knitCell * 0.48,
      height: knitCell * 0.96,
    );
    final matrix = Matrix4.identity()
      ..translateByDouble(x, knitCell / 2, 0, 1)
      ..rotateZ(angle);
    return (Path()..addOval(rect)).transform(matrix.storage);
  }

  const angle = 24 * pi / 180;
  return Path()
    ..addPath(leg(knitCell * 0.28, -angle), Offset.zero)
    ..addPath(leg(knitCell * 0.72, angle), Offset.zero);
}();

/// Paints [size] in stitches on [base] wool: the color [colorAt] gives a
/// cell, or else [stitch], the color of the plain knitting. The cells start
/// at [origin], at most one cell before the top left corner, so that a cell
/// can sit right in the middle, see [_origin].
void _paintStitches(
  Canvas canvas,
  Size size,
  Color? Function(int row, int col) colorAt, {
  required Color base,
  required Color stitch,
  Offset origin = Offset.zero,
}) {
  final rows = ((size.height - origin.dy) / knitCell).ceil();
  final cols = ((size.width - origin.dx) / knitCell).ceil();
  final legs = <Color, Path>{};
  final wool = <Color, Path>{};
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final offset = origin + Offset(col * knitCell, row * knitCell);
      final color = colorAt(row, col);
      if (color != null) {
        (wool[color == _white ? _whiteWool : _redWool] ??= Path()).addRect(
          offset & const Size(knitCell, knitCell),
        );
      }
      (legs[color ?? stitch] ??= Path()).addPath(_stitch, offset);
    }
  }
  canvas.drawRect(Offset.zero & size, Paint()..color = base);
  for (final MapEntry(key: color, value: path) in wool.entries) {
    canvas.drawPath(path, Paint()..color = color);
  }
  for (final MapEntry(key: color, value: path) in legs.entries) {
    canvas.drawPath(path, Paint()..color = color);
  }
}

/// Where the cells start along a [length], so that one of them sits right
/// in its middle: the odd motifs then center on it to the pixel.
double _origin(double length) =>
    (length / 2 - knitCell / 2) % knitCell - knitCell;

/// Index of the cell, starting at [origin], whose center is closest to
/// [pixels].
int _cellAt(double pixels, double origin) =>
    ((pixels - knitCell / 2 - origin) / knitCell).round();

/// Puts [motif], centered on the cell ([row], [col]), into [cells].
void _stamp(
  Map<(int, int), Color> cells,
  List<String> motif,
  int row,
  int col,
  Color color,
) {
  final top = row - motif.length ~/ 2;
  final left = col - motif.first.length ~/ 2;
  for (final (r, line) in motif.indexed) {
    for (var c = 0; c < line.length; c++) {
      if (line[c] == '#') cells[(top + r, left + c)] = color;
    }
  }
}

/// The pill of the tab bar knitted for Christmas: blue wool, a row of white
/// dots along each long edge, the tab icons in white, and the selected tab
/// on a patch of red wool, shaped like the usual selection. Laid out like
/// the tabs of the pill: [padding] around them and [gap] between two of them.
class KnitTabBackground extends CustomPainter {
  KnitTabBackground({
    required this.colors,
    required this.motifs,
    required this.selection,
    required this.vertical,
    required this.padding,
    required this.gap,
  });

  final AppColors colors;

  /// Motif of each tab, in order.
  final List<List<String>> motifs;

  /// Index of the selected tab, between two while the patch slides.
  final double selection;
  final bool vertical;
  final double padding;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final length = vertical ? size.height : size.width;
    final thickness = vertical ? size.width : size.height;
    final count = motifs.length;
    final tab = (length - 2 * padding - gap * (count - 1)) / count;
    double tabStart(double index) => padding + index * (tab + gap);

    // Across the bar, a cell in the middle; along it, the cells from the
    // start, each icon on the cell closest to the middle of its tab.
    final crossOrigin = _origin(thickness);
    final crossCells = ((thickness - crossOrigin) / knitCell).ceil();
    final crossCenter = _cellAt(thickness / 2, crossOrigin);
    // Along the bar, the start of the cells that puts the middles of the
    // tabs closest to the middles of cells: the tabs are not a whole number
    // of cells apart.
    final middles = [
      for (var i = 0; i < count; i++) tabStart(i.toDouble()) + tab / 2,
    ];
    double misfit(double origin) => middles
        .map((m) {
          final off = (m - knitCell / 2 - origin) % knitCell;
          return pow(min(off, knitCell - off), 2).toDouble();
        })
        .fold(0.0, (a, b) => a + b);
    final mainOrigin = [
      for (var k = 0; k < 8; k++) -knitCell + k * knitCell / 8,
    ].reduce((a, b) => misfit(a) <= misfit(b) ? a : b);
    final mainCells = ((length - mainOrigin) / knitCell).ceil();
    final cells = <(int, int), Color>{};
    // (main, cross) → (row, col).
    void put(int main, int cross, Color color) =>
        cells[vertical ? (main, cross) : (cross, main)] = color;

    // The dots along the long edges.
    for (var main = 1; main < mainCells - 1; main += 3) {
      put(main, 1, _white);
      put(main, crossCells - 2, _white);
    }

    // The red patch: the stitches whose middle falls in the pill of the
    // usual selection, inside the padding of the bar.
    final start = tabStart(selection);
    final patch = RRect.fromLTRBR(
      start,
      padding,
      start + tab,
      thickness - padding,
      Radius.circular(min(tab, thickness - 2 * padding) / 2),
    );
    for (
      var m = _cellAt(start, mainOrigin) - 1;
      m <= _cellAt(start + tab, mainOrigin) + 1;
      m++
    ) {
      for (var c = 0; c < crossCells; c++) {
        final middle = Offset(
          mainOrigin + m * knitCell + knitCell / 2,
          crossOrigin + c * knitCell + knitCell / 2,
        );
        if (patch.contains(middle)) put(m, c, colors.accent);
      }
    }

    // The icons, upright whatever the direction of the bar.
    final icons = <(int, int), Color>{};
    for (final (index, motif) in motifs.indexed) {
      final main = _cellAt(middles[index], mainOrigin);
      _stamp(
        icons,
        motif,
        vertical ? main : crossCenter,
        vertical ? crossCenter : main,
        _white,
      );
    }
    cells.addAll(icons);

    _paintStitches(
      canvas,
      size,
      (row, col) => cells[(row, col)],
      base: colors.knitBase,
      stitch: colors.knitStitch,
      origin: vertical
          ? Offset(crossOrigin, mainOrigin)
          : Offset(mainOrigin, crossOrigin),
    );
  }

  @override
  bool shouldRepaint(KnitTabBackground old) =>
      old.selection != selection ||
      old.colors != colors ||
      old.vertical != vertical ||
      old.motifs != motifs;
}

/// The round add button knitted in red, with a white plus in its middle.
class KnitButtonPainter extends CustomPainter {
  KnitButtonPainter(this.colors);

  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(_origin(size.width), _origin(size.height));
    final cells = <(int, int), Color>{};
    _stamp(
      cells,
      KnitMotifs.plus,
      _cellAt(size.height / 2, origin.dy),
      _cellAt(size.width / 2, origin.dx),
      _white,
    );
    _paintStitches(
      canvas,
      size,
      (row, col) => cells[(row, col)] ?? colors.accent,
      base: _redWool,
      stitch: colors.accent,
      origin: origin,
    );
  }

  @override
  bool shouldRepaint(KnitButtonPainter old) => old.colors != colors;
}
