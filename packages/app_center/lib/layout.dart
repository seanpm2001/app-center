import 'package:flutter/material.dart';

const kCardMargin = 4.0;
const kPaneWidth = 204.0;
const kPagePadding = 24.0;
const kCardSpacing = 16.0;
const kSearchBarWidth = 424.0 - 2 * kCardMargin;
const kIconSize = 56.0;

const kCardSizeNormal = Size(416.0, 170.0);
const kCardSizeWide = Size(548.0, 170.0);

const kBreakPointSmall = 1280.0;
const kBreakPointLarge = 1680.0;

enum ResponsiveLayoutType {
  small,
  medium,
  large,
}

class ResponsiveLayout extends InheritedWidget {
  ResponsiveLayout({
    super.key,
    required this.constraints,
    required super.child,
  }) {
    final (
      cardColumnCount,
      cardSize,
      snapInfoColumnCount,
      type,
      chartColumnCount
    ) = switch (constraints.maxWidth + kPaneWidth + 1) {
      // 1px for YaruNavigationRail's separator
      < kBreakPointSmall => (
          1,
          kCardSizeWide,
          3,
          ResponsiveLayoutType.small,
          1
        ),
      < kBreakPointLarge => (
          2,
          kCardSizeNormal,
          4,
          ResponsiveLayoutType.medium,
          2
        ),
      _ => (3, kCardSizeNormal, 6, ResponsiveLayoutType.large, 4),
    };
    this.cardColumnCount = cardColumnCount;
    this.cardSize = cardSize;
    this.snapInfoColumnCount = snapInfoColumnCount;
    this.type = type;
    this.chartColumnCount = chartColumnCount;
  }

  final BoxConstraints constraints;

  late final int cardColumnCount;
  late final Size cardSize;
  late final int snapInfoColumnCount;
  late final ResponsiveLayoutType type;
  late final int chartColumnCount;

  double get totalWidth =>
      cardColumnCount * cardSize.width + // cards
      (cardColumnCount - 1) * (kCardSpacing - 2 * kCardMargin) + // spacing
      2 * kCardMargin; // left+right margin of outermost cards

  EdgeInsets get padding => EdgeInsets.symmetric(
      horizontal: (constraints.maxWidth - totalWidth) / 2.0);

  static ResponsiveLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ResponsiveLayout>();

  static ResponsiveLayout of(BuildContext context) {
    final layout = ResponsiveLayout.maybeOf(context);
    assert(layout != null, 'No ResponsiveLayout found in this context');
    return layout!;
  }

  @override
  bool updateShouldNotify(covariant ResponsiveLayout oldWidget) {
    return oldWidget.constraints != constraints;
  }
}

class ResponsiveLayoutBuilder extends LayoutBuilder {
  ResponsiveLayoutBuilder({super.key, required WidgetBuilder builder})
      : super(
          builder: (context, constraints) => ResponsiveLayout(
            constraints: constraints,
            child: Builder(builder: builder),
          ),
        );
}

class ResponsiveLayoutScrollView extends StatelessWidget {
  const ResponsiveLayoutScrollView({super.key, this.slivers = const []});

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(builder: (context) {
      return CustomScrollView(
        slivers: slivers
            .map((s) => SliverPadding(
                  padding: ResponsiveLayout.of(context).padding,
                  sliver: s,
                ))
            .toList(),
      );
    });
  }
}
