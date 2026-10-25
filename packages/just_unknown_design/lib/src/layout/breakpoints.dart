import 'package:flutter/widgets.dart';

enum FormFactor { mobile, tablet, desktop }

abstract final class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double contentMaxWidth = 1120;
  static const double proseMaxWidth = 720;

  static FormFactor of(double width) {
    if (width < mobile) return FormFactor.mobile;
    if (width < tablet) return FormFactor.tablet;
    return FormFactor.desktop;
  }

  static double gutter(FormFactor f) => switch (f) {
    FormFactor.mobile => 20,
    FormFactor.tablet => 32,
    FormFactor.desktop => 48,
  };

  static int columns(FormFactor f, {int max = 3}) => switch (f) {
    FormFactor.mobile => 1,
    FormFactor.tablet => max.clamp(1, 2),
    FormFactor.desktop => max,
  };
}

extension ResponsiveX on BuildContext {
  double get viewportWidth => MediaQuery.sizeOf(this).width;
  FormFactor get formFactor => Breakpoints.of(viewportWidth);
  bool get isMobile => formFactor == FormFactor.mobile;
  bool get isDesktop => formFactor == FormFactor.desktop;
  bool get isCompact => formFactor != FormFactor.desktop;
  double get gutter => Breakpoints.gutter(formFactor);
}
