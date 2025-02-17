import 'dart:async';
import 'dart:ui';

import 'package:aves/app_flavor.dart';
import 'package:aves/app_mode.dart';
import 'package:aves/l10n/l10n.dart';
import 'package:aves/model/device.dart';
import 'package:aves/model/settings/enums/accessibility_animations.dart';
import 'package:aves/model/settings/enums/display_refresh_rate_mode.dart';
import 'package:aves/model/settings/enums/enums.dart';
import 'package:aves/model/settings/enums/screen_on.dart';
import 'package:aves/model/settings/enums/theme_brightness.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/media_store_source.dart';
import 'package:aves/services/accessibility_service.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/theme/colors.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/theme/themes.dart';
import 'package:aves/utils/android_file_utils.dart';
import 'package:aves/utils/debouncer.dart';
import 'package:aves/widgets/collection/collection_grid.dart';
import 'package:aves/widgets/collection/collection_page.dart';
import 'package:aves/widgets/common/behaviour/route_tracker.dart';
import 'package:aves/widgets/common/behaviour/routes.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/providers/highlight_info_provider.dart';
import 'package:aves/widgets/home_page.dart';
import 'package:aves/widgets/welcome_page.dart';
import 'package:equatable/equatable.dart';
import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class AvesApp extends StatefulWidget {
  final AppFlavor flavor;

  const AvesApp({
    Key? key,
    required this.flavor,
  }) : super(key: key);

  @override
  State<AvesApp> createState() => _AvesAppState();
}

class _AvesAppState extends State<AvesApp> with WidgetsBindingObserver {
  final ValueNotifier<AppMode> appModeNotifier = ValueNotifier(AppMode.main);
  late Future<void> _appSetup;
  final _mediaStoreSource = MediaStoreSource();
  final Debouncer _mediaStoreChangeDebouncer = Debouncer(delay: Durations.mediaContentChangeDebounceDelay);
  final Set<String> changedUris = {};

  // observers are not registered when using the same list object with different items
  // the list itself needs to be reassigned
  List<NavigatorObserver> _navigatorObservers = [];
  final EventChannel _mediaStoreChangeChannel = const EventChannel('deckers.thibault/aves/media_store_change');
  final EventChannel _newIntentChannel = const EventChannel('deckers.thibault/aves/intent');
  final EventChannel _analysisCompletionChannel = const EventChannel('deckers.thibault/aves/analysis_events');
  final EventChannel _errorChannel = const EventChannel('deckers.thibault/aves/error');
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey(debugLabel: 'app-navigator');

  Widget getFirstPage({Map? intentData}) => settings.hasAcceptedTerms ? HomePage(intentData: intentData) : const WelcomePage();

  @override
  void initState() {
    super.initState();
    EquatableConfig.stringify = true;
    _appSetup = _setup();
    _mediaStoreChangeChannel.receiveBroadcastStream().listen((event) => _onMediaStoreChange(event as String?));
    _newIntentChannel.receiveBroadcastStream().listen((event) => _onNewIntent(event as Map?));
    _analysisCompletionChannel.receiveBroadcastStream().listen((event) => _onAnalysisCompletion());
    _errorChannel.receiveBroadcastStream().listen((event) => _onError(event as String?));
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    // place the settings provider above `MaterialApp`
    // so it can be used during navigation transitions
    return Provider<AppFlavor>.value(
      value: widget.flavor,
      child: ChangeNotifierProvider<Settings>.value(
        value: settings,
        child: ListenableProvider<ValueNotifier<AppMode>>.value(
          value: appModeNotifier,
          child: Provider<CollectionSource>.value(
            value: _mediaStoreSource,
            child: DurationsProvider(
              child: HighlightInfoProvider(
                child: OverlaySupport(
                  child: FutureBuilder<void>(
                    future: _appSetup,
                    builder: (context, snapshot) {
                      final initialized = !snapshot.hasError && snapshot.connectionState == ConnectionState.done;
                      final home = initialized
                          ? getFirstPage()
                          : Scaffold(
                              body: snapshot.hasError ? _buildError(snapshot.error!) : const SizedBox(),
                            );
                      return Selector<Settings, Tuple3<Locale?, bool, AvesThemeBrightness>>(
                        selector: (context, s) => Tuple3(
                          s.locale,
                          s.initialized ? s.accessibilityAnimations.animate : true,
                          s.initialized ? s.themeBrightness : AvesThemeBrightness.system,
                        ),
                        builder: (context, s, child) {
                          final settingsLocale = s.item1;
                          final areAnimationsEnabled = s.item2;
                          final themeBrightness = s.item3;
                          return MaterialApp(
                            navigatorKey: _navigatorKey,
                            home: home,
                            navigatorObservers: _navigatorObservers,
                            builder: (context, child) {
                              // Flutter has various page transition implementations for Android:
                              // - `FadeUpwardsPageTransitionsBuilder` on Oreo / API 27 and below
                              // - `OpenUpwardsPageTransitionsBuilder` on Pie / API 28
                              // - `ZoomPageTransitionsBuilder` on Android 10 / API 29 and above
                              // As of Flutter v2.8.1, `FadeUpwardsPageTransitionsBuilder` is the default, regardless of versions.
                              // In practice, `ZoomPageTransitionsBuilder` feels unstable when transitioning from Album to Collection.
                              if (!areAnimationsEnabled) {
                                child = Theme(
                                  data: Theme.of(context).copyWith(
                                    // strip page transitions used by `MaterialPageRoute`
                                    pageTransitionsTheme: DirectPageTransitionsTheme(),
                                  ),
                                  child: child!,
                                );
                              }
                              return AvesColorsProvider(
                                child: child!,
                              );
                              // return child!;
                            },
                            onGenerateTitle: (context) => context.l10n.appName,
                            theme: Themes.lightTheme,
                            darkTheme: themeBrightness == AvesThemeBrightness.black ? Themes.blackTheme : Themes.darkTheme,
                            themeMode: themeBrightness.appThemeMode,
                            locale: settingsLocale,
                            localizationsDelegates: AppLocalizations.localizationsDelegates,
                            supportedLocales: AppLocalizations.supportedLocales,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AIcons.error),
          const SizedBox(height: 16),
          Text(error.toString()),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('$runtimeType lifecycle ${state.name}');
    switch (state) {
      case AppLifecycleState.inactive:
        switch (appModeNotifier.value) {
          case AppMode.main:
          case AppMode.pickMediaExternal:
            _saveTopEntries();
            break;
          case AppMode.pickMediaInternal:
          case AppMode.pickFilterInternal:
          case AppMode.view:
            break;
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.resumed:
        break;
    }
  }

  // save IDs of entries visible at the top of the collection page with current layout settings
  void _saveTopEntries() {
    if (!settings.initialized) return;

    final stopwatch = Stopwatch()..start();
    final screenSize = window.physicalSize / window.devicePixelRatio;
    var tileExtent = settings.getTileExtent(CollectionPage.routeName);
    if (tileExtent == 0) {
      tileExtent = screenSize.shortestSide / CollectionGrid.columnCountDefault;
    }
    final rows = (screenSize.height / tileExtent).ceil();
    final columns = (screenSize.width / tileExtent).ceil();
    final count = rows * columns;
    final collection = CollectionLens(source: _mediaStoreSource, listenToSource: false);
    settings.topEntryIds = collection.sortedEntries.take(count).map((entry) => entry.id).toList();
    collection.dispose();
    debugPrint('Saved $count top entries in ${stopwatch.elapsed.inMilliseconds}ms');
  }

  // setup before the first page is displayed. keep it short
  Future<void> _setup() async {
    final stopwatch = Stopwatch()..start();

    await device.init();
    await settings.init(monitorPlatformSettings: true);
    settings.isRotationLocked = await windowService.isRotationLocked();
    settings.areAnimationsRemoved = await AccessibilityService.areAnimationsRemoved();
    _monitorSettings();

    FijkLog.setLevel(FijkLogLevel.Warn);
    unawaited(_setupErrorReporting());

    debugPrint('App setup in ${stopwatch.elapsed.inMilliseconds}ms');
  }

  void _monitorSettings() {
    void applyIsInstalledAppAccessAllowed() {
      if (settings.isInstalledAppAccessAllowed) {
        androidFileUtils.initAppNames();
      } else {
        androidFileUtils.resetAppNames();
      }
    }

    void applyDisplayRefreshRateMode() => settings.displayRefreshRateMode.apply();
    void applyKeepScreenOn() => settings.keepScreenOn.apply();

    void applyIsRotationLocked() {
      if (!settings.isRotationLocked) {
        windowService.requestOrientation();
      }
    }

    settings.updateStream.where((event) => event.key == Settings.isInstalledAppAccessAllowedKey).listen((_) => applyIsInstalledAppAccessAllowed());
    settings.updateStream.where((event) => event.key == Settings.displayRefreshRateModeKey).listen((_) => applyDisplayRefreshRateMode());
    settings.updateStream.where((event) => event.key == Settings.keepScreenOnKey).listen((_) => applyKeepScreenOn());
    settings.updateStream.where((event) => event.key == Settings.platformAccelerometerRotationKey).listen((_) => applyIsRotationLocked());

    applyDisplayRefreshRateMode();
    applyKeepScreenOn();
    applyIsRotationLocked();
  }

  Future<void> _setupErrorReporting() async {
    await reportService.init();
    settings.updateStream.where((event) => event.key == Settings.isErrorReportingAllowedKey).listen(
          (_) => reportService.setCollectionEnabled(settings.isErrorReportingAllowed),
        );
    await reportService.setCollectionEnabled(settings.isErrorReportingAllowed);

    FlutterError.onError = reportService.recordFlutterError;
    final now = DateTime.now();
    final hasPlayServices = await availability.hasPlayServices;
    await reportService.setCustomKeys({
      'build_mode': kReleaseMode
          ? 'release'
          : kProfileMode
              ? 'profile'
              : 'debug',
      'has_play_services': hasPlayServices,
      'locales': WidgetsBinding.instance!.window.locales.join(', '),
      'time_zone': '${now.timeZoneName} (${now.timeZoneOffset})',
    });
    _navigatorObservers = [
      ReportingRouteTracker(),
    ];
  }

  void _onNewIntent(Map? intentData) {
    debugPrint('$runtimeType onNewIntent with intentData=$intentData');

    // do not reset when relaunching the app
    if (appModeNotifier.value == AppMode.main && (intentData == null || intentData.isEmpty == true)) return;

    reportService.log('New intent');
    _navigatorKey.currentState!.pushReplacement(DirectMaterialPageRoute(
      settings: const RouteSettings(name: HomePage.routeName),
      builder: (_) => getFirstPage(intentData: intentData),
    ));
  }

  Future<void> _onAnalysisCompletion() async {
    debugPrint('Analysis completed');
    await _mediaStoreSource.loadCatalogMetadata();
    await _mediaStoreSource.loadAddresses();
    _mediaStoreSource.updateDerivedFilters();
  }

  void _onMediaStoreChange(String? uri) {
    if (uri != null) changedUris.add(uri);
    if (changedUris.isNotEmpty) {
      _mediaStoreChangeDebouncer(() async {
        final todo = changedUris.toSet();
        changedUris.clear();
        final tempUris = await _mediaStoreSource.refreshUris(todo);
        if (tempUris.isNotEmpty) {
          changedUris.addAll(tempUris);
          _onMediaStoreChange(null);
        }
      });
    }
  }

  void _onError(String? error) => reportService.recordError(error, null);
}
