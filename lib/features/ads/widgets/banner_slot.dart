/// Banner ad slot for Home/Browse. Collapses to zero height whenever the
/// SDK is unavailable or no ad loads (e.g. offline) — layouts never shift
/// by exception.
library;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads_service.dart';

class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key});

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    if (AdsService.instance.available) {
      AdsService.instance.createBanner().then((ad) {
        if (mounted) setState(() => _ad = ad);
      });
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
