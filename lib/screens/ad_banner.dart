import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../data/app_state.dart';
import '../services/ad_service.dart';

/// An anchored adaptive banner for the bottom of a screen. Takes no space until an
/// ad has loaded, and none at all after "Remove ads".
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  // No retry on every rebuild after a failed load; a new width (rotation) tries again.
  bool _failed = false;
  bool _loading = false;
  int? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (!state.showAds) {
      _dispose();
    } else if ((_ad == null && !_failed && !_loading) || width != _width) {
      _load(width);
    }
  }

  Future<void> _load(int width) async {
    _dispose();
    _failed = false;
    _width = width;
    _loading = true;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (_width != width) return; // a newer load took over
    _loading = false;
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: AdUnits.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner: ${error.message}');
          ad.dispose();
          if (mounted && identical(_ad, ad)) {
            setState(() {
              _ad = null;
              _failed = true;
            });
          }
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  void _dispose() {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded || !AppScope.of(context).showAds) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
