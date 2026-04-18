import 'package:flutter/widgets.dart';

/// Small responsive helpers. Choose a base design width (e.g. 360) and height
/// (e.g. 800). Use `Responsive.init(context)` once per screen (or call the
/// helpers with context) and then use [w], [h], [sp] to scale sizes.
class Responsive {
  static const double _baseWidth = 360.0;
  static const double _baseHeight = 800.0;

  /// scale factor based on width
  static double w(BuildContext context, double px) {
    final width = MediaQuery.of(context).size.width;
    return px * (width / _baseWidth);
  }

  /// scale factor based on height
  static double h(BuildContext context, double px) {
    final height = MediaQuery.of(context).size.height;
    return px * (height / _baseHeight);
  }

  /// scale text by width factor
  static double sp(BuildContext context, double px) {
    return w(context, px);
  }
}
