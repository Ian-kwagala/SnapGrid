import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages Google AdMob ads and UMP privacy consent while keeping offline
/// sessions clean and using Google's official Test Ad IDs during development.
class AdService {
  AdService({bool? enableMobileAds})
      : _isSupportedPlatform = enableMobileAds ??
            (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  final bool _isSupportedPlatform;

  // Official Google Mobile Ads Test Ad Unit IDs (safe during development).
  static const String _testBannerId = 'ca-app-pub-3940256099942544/9214589741';
  static const String _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedId = 'ca-app-pub-3940256099942544/5224354917';

  bool _adsInitialized = false;
  bool _canRequestAds = false;

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  final ValueNotifier<bool> bannerReady = ValueNotifier<bool>(false);
  final ValueNotifier<bool> rewardedReady = ValueNotifier<bool>(false);

  bool get isSupportedPlatform => _isSupportedPlatform;
  bool get isBannerLoaded => _isBannerLoaded && _bannerAd != null;
  bool get isRewardedReady => _rewardedAd != null || !_isSupportedPlatform;

  /// Requests UMP privacy consent (Europe/UK) and initializes MobileAds SDK.
  Future<void> initialize() async {
    if (!_isSupportedPlatform) {
      rewardedReady.value = true;
      return;
    }

    final Completer<void> completer = Completer<void>();
    final ConsentRequestParameters params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        _canRequestAds = await ConsentInformation.instance.canRequestAds();
        if (_canRequestAds) {
          await _initMobileAds();
        }
        if (!completer.isCompleted) completer.complete();
      },
      (_) async {
        // Offline or consent check failed: continue smoothly without blocking.
        _canRequestAds = await ConsentInformation.instance.canRequestAds();
        if (_canRequestAds) {
          await _initMobileAds();
        }
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future;
  }

  Future<void> _initMobileAds() async {
    if (_adsInitialized) return;
    _adsInitialized = true;
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
  }

  /// Loads an adaptive banner sized for [widthPx]; hides itself cleanly offline.
  Future<void> loadAdaptiveBanner(int widthPx) async {
    if (!_isSupportedPlatform || !_canRequestAds || widthPx <= 0) return;

    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(widthPx);
    if (size == null) return;

    _bannerAd?.dispose();
    _isBannerLoaded = false;
    bannerReady.value = false;

    final BannerAd banner = BannerAd(
      adUnitId: _testBannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerAd = ad as BannerAd;
          _isBannerLoaded = true;
          bannerReady.value = true;
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerAd = null;
          _isBannerLoaded = false;
          bannerReady.value = false;
        },
      ),
    );
    await banner.load();
  }

  Widget buildBannerWidget() {
    if (!_isBannerLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  void _loadInterstitial() {
    if (!_isSupportedPlatform || !_canRequestAds) return;
    InterstitialAd.load(
      adUnitId: _testInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void _loadRewarded() {
    if (!_isSupportedPlatform || !_canRequestAds) return;
    RewardedAd.load(
      adUnitId: _testRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          rewardedReady.value = true;
        },
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
          rewardedReady.value = false;
        },
      ),
    );
  }

  /// Shows a full-screen interstitial only once every 2 finished games.
  Future<void> showInterstitialIfEligible({
    required int gamesFinishedCount,
  }) async {
    if (!_isSupportedPlatform || gamesFinishedCount % 2 != 0) {
      return;
    }
    final InterstitialAd? ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    final Completer<void> completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
    );
    await ad.show();
    await completer.future;
  }

  /// Shows a Rewarded Video ad and returns true when the player earns the reward.
  Future<bool> showRewardedAd() async {
    if (!_isSupportedPlatform) {
      // Desktop / test mode simulates a completed rewarded test ad.
      return true;
    }
    final RewardedAd? ad = _rewardedAd;
    if (ad == null) {
      _loadRewarded();
      return false;
    }

    bool earnedReward = false;
    final Completer<bool> completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        rewardedReady.value = false;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        rewardedReady.value = false;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (_, _) {
        earnedReward = true;
      },
    );
    return completer.future;
  }

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    bannerReady.dispose();
    rewardedReady.dispose();
  }
}
