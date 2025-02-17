import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/source/enums.dart';
import 'package:aves/model/source/section_keys.dart';
import 'package:aves/widgets/common/grid/section_layout.dart';
import 'package:aves/widgets/filter_grids/common/section_header.dart';
import 'package:aves/widgets/filter_grids/common/section_keys.dart';
import 'package:flutter/material.dart';

class SectionedFilterListLayoutProvider<T extends CollectionFilter> extends SectionedListLayoutProvider<FilterGridItem<T>> {
  const SectionedFilterListLayoutProvider({
    Key? key,
    required this.sections,
    required this.showHeaders,
    required double scrollableWidth,
    required TileLayout tileLayout,
    required int columnCount,
    required double spacing,
    required double horizontalPadding,
    required double tileWidth,
    required double tileHeight,
    required Widget Function(FilterGridItem<T> gridItem) tileBuilder,
    required Duration tileAnimationDelay,
    required Widget child,
  }) : super(
          key: key,
          scrollableWidth: scrollableWidth,
          tileLayout: tileLayout,
          columnCount: columnCount,
          spacing: spacing,
          horizontalPadding: horizontalPadding,
          tileWidth: tileWidth,
          tileHeight: tileHeight,
          tileBuilder: tileBuilder,
          tileAnimationDelay: tileAnimationDelay,
          child: child,
        );

  @override
  final Map<SectionKey, List<FilterGridItem<T>>> sections;

  @override
  final bool showHeaders;

  @override
  double getHeaderExtent(BuildContext context, SectionKey sectionKey) {
    return FilterChipSectionHeader.getPreferredHeight(context);
  }

  @override
  Widget buildHeader(BuildContext context, SectionKey sectionKey, double headerExtent) {
    return FilterChipSectionHeader<FilterGridItem<T>>(
      sectionKey: sectionKey as ChipSectionKey,
    );
  }
}
