import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'enums.dart';

extension ExtraDisplayRefreshRateMode on DisplayRefreshRateMode {
  String getName(BuildContext context) {
    switch (this) {
      case DisplayRefreshRateMode.auto:
        return context.l10n.settingsSystemDefault;
      case DisplayRefreshRateMode.highest:
        return context.l10n.displayRefreshRatePreferHighest;
      case DisplayRefreshRateMode.lowest:
        return context.l10n.displayRefreshRatePreferLowest;
    }
  }

  void apply() {
    debugPrint('Apply display refresh rate: $name');
    switch (this) {
      case DisplayRefreshRateMode.auto:
        FlutterDisplayMode.setPreferredMode(DisplayMode.auto);
        break;
      case DisplayRefreshRateMode.highest:
        FlutterDisplayMode.setHighRefreshRate();
        break;
      case DisplayRefreshRateMode.lowest:
        FlutterDisplayMode.setLowRefreshRate();
        break;
    }
  }
}
