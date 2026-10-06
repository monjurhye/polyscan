import 'package:flutter/material.dart';

import '../screens/pro_screen.dart';

/// Reserves the space the AdMob banner will use on the free tier.
class AdBannerPlaceholder extends StatelessWidget {
  const AdBannerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen())),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Ad', style: TextStyle(fontSize: 11, color: scheme.outline)),
              ),
              const SizedBox(width: 10),
              Text('Ads keep Polyscan free · ', style: TextStyle(color: scheme.onSurfaceVariant)),
              Text('Remove with Pro', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
