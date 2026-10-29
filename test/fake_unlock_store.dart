import 'dart:async';

import 'package:polyscan/services/unlock_store.dart';

/// An [UnlockStore] for tests: no platform channels, purchases succeed or fail on demand.
class FakeUnlockStore implements UnlockStore {
  FakeUnlockStore({this.priceText = r'$4.99', this.owned = false});

  final String? priceText;

  /// Whether the store has a purchase that [restore] finds.
  bool owned;

  /// When set, [buy] fails with this message instead of unlocking.
  String? failWith;

  final _events = StreamController<UnlockEvent>.broadcast(sync: true);

  @override
  Stream<UnlockEvent> get events => _events.stream;

  @override
  Future<String?> price() async => priceText;

  @override
  Future<void> buy() async {
    if (failWith != null) {
      _events.add(UnlockFailed(failWith!));
      return;
    }
    owned = true;
    _events.add(const Unlocked());
  }

  @override
  Future<void> restore() async {
    if (owned) _events.add(const Unlocked());
  }
}
