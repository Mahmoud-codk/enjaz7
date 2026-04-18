import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service class to manage all AdMob ads (App Open, Interstitial, and utilities)
class AdService {
  static InterstitialAd? _interstitialAd;
  static AppOpenAd? _appOpenAd;
  
  static bool _isInterstitialAdLoading = false;
  static bool _isAppOpenAdLoading = false;
  
  static bool _isInterstitialAdLoaded = false;
  static bool _isAppOpenAdLoaded = false;

  // Ad Unit IDs
  static const String interstitialUnitId = 'ca-app-pub-5517764020832780/9131069616';
  static const String appOpenUnitId = 'ca-app-pub-5517764020832780/9347167390';

  /// Initialize and load all initial ads (App Open + Interstitial)
  static Future<void> loadInitialAds() async {
    loadAppOpenAd();
    loadInterstitialAd();
  }

  /// Load App Open Ad
  static Future<void> loadAppOpenAd() async {
    if (_isAppOpenAdLoading || _isAppOpenAdLoaded) return;
    _isAppOpenAdLoading = true;

    await AppOpenAd.load(
      adUnitId: appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenAdLoaded = true;
          _isAppOpenAdLoading = false;
          debugPrint('✅ App Open Ad loaded successfully');
        },
        onAdFailedToLoad: (error) {
          _isAppOpenAdLoading = false;
          _isAppOpenAdLoaded = false;
          debugPrint('❌ App Open Ad failed to load: $error');
        },
      ),
    );
  }

  /// Show App Open Ad and then Interstitial Ad sequentially
  static Future<void> showStartupAds() async {
    if (_appOpenAd != null) {
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _appOpenAd = null;
          _isAppOpenAdLoaded = false;
          loadAppOpenAd(); // Load next one
          
          // Show interstitial after app open is dismissed
          Timer(const Duration(milliseconds: 1000), () {
            showInterstitialAd();
          });
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _appOpenAd = null;
          _isAppOpenAdLoaded = false;
          showInterstitialAd(); // Fallback to interstitial
        },
      );
      await _appOpenAd!.show();
    } else {
      // Fallback: if no App Open ad, try Interstitial
      showInterstitialAd();
    }
  }

  /// Load Interstitial Ad
  static Future<void> loadInterstitialAd() async {
    if (_isInterstitialAdLoading || _isInterstitialAdLoaded) return;
    _isInterstitialAdLoading = true;
    
    await InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          _isInterstitialAdLoading = false;
          debugPrint('✅ Interstitial Ad loaded successfully');
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoading = false;
          _isInterstitialAdLoaded = false;
          debugPrint('❌ Interstitial Ad failed to load: $error');
        },
      ),
    );
  }

  /// Show Interstitial Ad (general trigger for Search and "I'm on the bus")
  static Future<void> showInterstitialAd() async {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
          loadInterstitialAd(); // Load next one
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
          loadInterstitialAd();
        },
      );
      await _interstitialAd!.show();
    } else {
      // If no ad is loaded, try to load one for next time
      loadInterstitialAd();
    }
  }

  /// Show Interstitial Ad after search (with custom delay)
  static Future<void> showInterstitialAdAfterSearch({int delayMs = 1000}) async {
    await Future.delayed(Duration(milliseconds: delayMs));
    await showInterstitialAd();
  }

  /// Cleanup
  static void dispose() {
    _interstitialAd?.dispose();
    _appOpenAd?.dispose();
    _isInterstitialAdLoaded = false;
    _isAppOpenAdLoaded = false;
  }
}
