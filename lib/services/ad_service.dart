import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob ad unit IDs. Release builds get the real ones with --dart-define (see
/// codemagic.yaml); every other build uses Google's test units, which are safe to tap.
class AdUnits {
  static String get banner => Platform.isIOS
      ? const String.fromEnvironment('ADMOB_IOS_BANNER', defaultValue: 'ca-app-pub-3940256099942544/2435281174')
      : const String.fromEnvironment('ADMOB_ANDROID_BANNER', defaultValue: 'ca-app-pub-3940256099942544/9214589741');

  static String get interstitial => Platform.isIOS
      ? const String.fromEnvironment('ADMOB_IOS_INTERSTITIAL', defaultValue: 'ca-app-pub-3940256099942544/4411468910')
      : const String.fromEnvironment('ADMOB_ANDROID_INTERSTITIAL', defaultValue: 'ca-app-pub-3940256099942544/1033173712');

  static String get appOpen => Platform.isIOS
      ? const String.fromEnvironment('ADMOB_IOS_APP_OPEN', defaultValue: 'ca-app-pub-3940256099942544/5575463023')
      : const String.fromEnvironment('ADMOB_ANDROID_APP_OPEN', defaultValue: 'ca-app-pub-3940256099942544/9257395921');
}

/// Banner, interstitial and app open ads, within AdMob's placement rules:
/// - consent first (Google's UMP form where the law needs it, then Apple's tracking prompt);
/// - full-screen ads only at natural breaks (a scan saved, a share finished, coming
///   back to the app), never at launch, never in the middle of a task;
/// - at most one full-screen ad per [minGap], and none while the user is in the
///   camera, a picker, the share sheet or a purchase ([hold]).
class AdService extends ChangeNotifier {
  AdService({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  static const minGap = Duration(seconds: 90);

  /// Shorter trips away (checking a message) don't earn an app open ad.
  static const minAway = Duration(seconds: 30);

  /// Google: an app open ad more than four hours old is stale.
  static const appOpenMaxAge = Duration(hours: 4);

  final DateTime Function() _now;

  /// Ads may be requested: consent is settled and the SDK has started.
  bool get ready => _ready;
  bool _ready = false;
  bool _stopped = false;

  /// Whether Settings must offer "Privacy choices" (UMP, for example in the EEA).
  bool get privacyOptionsRequired => _privacyOptionsRequired;
  bool _privacyOptionsRequired = false;

  InterstitialAd? _interstitial;
  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;
  DateTime? _lastFullScreen;
  DateTime? _wentAway;
  bool _showing = false;
  int _holds = 0;
  AppLifecycleListener? _lifecycle;

  /// Asks for consent, starts the SDK and preloads the full-screen ads. Call once,
  /// after the first frame; does nothing more after [stop].
  Future<void> start() async {
    if (_ready || _stopped) return;
    await _gatherConsent();
    if (Platform.isIOS && await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
    if (_stopped || !await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    _privacyOptionsRequired = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    _ready = true;
    // No full-screen ad within [minGap] of starting up.
    _lastFullScreen = _now();
    _lifecycle = AppLifecycleListener(onHide: () => _wentAway = _now(), onShow: _onReturn);
    _loadInterstitial();
    _loadAppOpen();
    notifyListeners();
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) debugPrint('Consent form: ${error.message}');
        done.complete();
      }),
      (error) {
        // Offline or misconfigured: canRequestAds() still answers from the last consent.
        debugPrint('Consent update: ${error.message}');
        done.complete();
      },
    );
    return done.future;
  }

  /// Shows Google's privacy options form (Settings › Privacy choices).
  Future<void> showPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) debugPrint('Privacy options: ${error.message}');
      });

  /// Turns ads off for good (the user bought "Remove ads").
  void stop() {
    _stopped = true;
    _ready = false;
    _interstitial?.dispose();
    _interstitial = null;
    _appOpen?.dispose();
    _appOpen = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    notifyListeners();
  }

  /// Runs [task] (camera, picker, share sheet, purchase) with app open ads held back,
  /// since leaving for those screens can look like leaving the app.
  Future<T> hold<T>(Future<T> Function() task) async {
    _holds++;
    try {
      return await task();
    } finally {
      _holds--;
      // The return from the task itself is not a trip away.
      _wentAway = null;
    }
  }

  bool get _gapPassed => _lastFullScreen == null || _now().difference(_lastFullScreen!) >= minGap;

  /// Shows an interstitial at a natural break, if one is loaded and the gap has passed.
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (!_ready || _showing || ad == null || !_gapPassed) return;
    _interstitial = null;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) => _finished(ad, _loadInterstitial),
      onAdFailedToShowFullScreenContent: (ad, error) => _finished(ad, _loadInterstitial),
    );
    await ad.show();
  }

  void _onReturn() {
    final away = _wentAway;
    _wentAway = null;
    if (!_ready || _showing || _holds > 0 || away == null) return;
    if (_now().difference(away) < minAway || !_gapPassed) return;
    final ad = _appOpen;
    if (ad == null || _now().difference(_appOpenLoadedAt!) > appOpenMaxAge) {
      _appOpen?.dispose();
      _appOpen = null;
      _loadAppOpen();
      return;
    }
    _appOpen = null;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) => _finished(ad, _loadAppOpen),
      onAdFailedToShowFullScreenContent: (ad, error) => _finished(ad, _loadAppOpen),
    );
    ad.show();
  }

  /// Called when a full-screen ad closes (or fails to show): starts the gap, loads the next one.
  void _finished(Ad ad, VoidCallback reload) {
    ad.dispose();
    _showing = false;
    _lastFullScreen = _now();
    if (_ready) reload();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdUnits.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!_ready) {
            ad.dispose();
            return;
          }
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) => debugPrint('Interstitial: ${error.message}'),
      ),
    );
  }

  void _loadAppOpen() {
    AppOpenAd.load(
      adUnitId: AdUnits.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          if (!_ready) {
            ad.dispose();
            return;
          }
          _appOpen = ad;
          _appOpenLoadedAt = _now();
        },
        onAdFailedToLoad: (error) => debugPrint('App open: ${error.message}'),
      ),
    );
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
