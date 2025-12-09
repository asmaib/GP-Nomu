import 'package:cloud_firestore/cloud_firestore.dart';

class TradingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> ensureWallet(String uid) async {
    final wref = _db.collection('users').doc(uid).collection('wallet').doc('main');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(wref);
      if (!snap.exists) {
        tx.set(wref, {
          'cash': 10000.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ---- Robust position locators ----
  Future<DocumentReference<Map<String, dynamic>>?> _findPositionRef(
      String uid, {
        required String symbol,
        required String companyName,
      }) async {
    final col = _db.collection('users').doc(uid).collection('positions');

    // 1) positions/{symbol}
    final p1 = col.doc(symbol);
    final s1 = await p1.get();
    if (s1.exists) return p1;

    // 2) positions/{companyName}
    final p2 = col.doc(companyName);
    final s2 = await p2.get();
    if (s2.exists) return p2;

    // 3) any doc where symbol == symbol
    final q1 = await col.where('symbol', isEqualTo: symbol).limit(1).get();
    if (q1.docs.isNotEmpty) return q1.docs.first.reference;

    // 4) any doc where name == companyName
    final q2 = await col.where('name', isEqualTo: companyName).limit(1).get();
    if (q2.docs.isNotEmpty) return q2.docs.first.reference;

    return null;
  }

  Future<int> getPositionQty({
    required String uid,
    required String symbol,
    required String companyName,
  }) async {
    final ref = await _findPositionRef(uid, symbol: symbol, companyName: companyName);
    if (ref == null) return 0;
    final snap = await ref.get();
    if (!snap.exists) return 0;
    final data = snap.data();
    if (data == null) return 0;
    final q = data['qty'];
    if (q is int) return q;
    if (q is num) return q.toInt();
    return 0;
  }

  /// Creates/updates a position. We normalize to use {symbol} as doc id,
  /// but we also migrate legacy docs if we touch them.
  Future<DocumentReference<Map<String, dynamic>>> _upsertPositionRef(
      String uid, {
        required String symbol,
        required String companyName,
      }) async {
    final col = _db.collection('users').doc(uid).collection('positions');

    // Prefer {symbol}
    final preferred = col.doc(symbol);
    final s = await preferred.get();
    if (s.exists) return preferred;

    // If legacy exists (by name), migrate its content into {symbol}
    final legacy = await _findPositionRef(uid, symbol: symbol, companyName: companyName);
    if (legacy != null) {
      final legacySnap = await legacy.get();
      if (legacySnap.exists && legacy.path != preferred.path) {
        await preferred.set(legacySnap.data() ?? {}, SetOptions(merge: true));
        await legacy.delete();
      }
    }
    return preferred;
  }

  Future<Map<String, dynamic>> placeOrder({
    required String uid,
    required String companyId,
    required String symbol,
    required String name,
    required String side, // 'BUY' or 'SELL'
    required int qty,
    required double price,
    required DateTime simDate,
  }) async {
    final walletRef = _db.collection('users').doc(uid).collection('wallet').doc('main');
    final ordersCol = _db.collection('users').doc(uid).collection('orders');
    final positionsCol = _db.collection('users').doc(uid).collection('positions');

    return await _db.runTransaction((tx) async {
      // wallet
      final wSnap = await tx.get(walletRef);
      if (!wSnap.exists) {
        tx.set(walletRef, {'cash': 10000.0, 'createdAt': FieldValue.serverTimestamp()});
      }
      final walletData = (await tx.get(walletRef)).data() ?? {};
      final double cash = (walletData['cash'] is num) ? (walletData['cash'] as num).toDouble() : 0.0;

      // position (robust read)
      DocumentReference<Map<String, dynamic>>? posRef =
      await _findPositionRef(uid, symbol: symbol, companyName: name);
      Map<String, dynamic> posData = {};
      if (posRef != null) {
        final ps = await tx.get(posRef);
        posData = ps.data() ?? {};
      }

      int currentQty = (posData['qty'] is num) ? (posData['qty'] as num).toInt() : 0;
      double avgCost = (posData['avgCost'] is num) ? (posData['avgCost'] as num).toDouble() : 0.0;

      final cost = price * qty;

      if (side == 'BUY') {
        if (cash < cost) {
          throw Exception('INSUFFICIENT_CASH');
        }
        // avg cost
        final newQty = currentQty + qty;
        final newAvg = (currentQty == 0) ? price : ((avgCost * currentQty) + cost) / newQty;

        // ensure normalized ref
        posRef = await _upsertPositionRef(uid, symbol: symbol, companyName: name);

        tx.set(
          posRef,
          {
            'symbol': symbol,
            'name': name,
            'qty': newQty,
            'avgCost': double.parse(newAvg.toStringAsFixed(6)),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        tx.update(walletRef, {'cash': cash - cost});
      } else {
        // SELL
        if (currentQty < qty) {
          throw Exception('INSUFFICIENT_SHARES');
        }

        // ensure normalized ref
        posRef = await _upsertPositionRef(uid, symbol: symbol, companyName: name);

        final remain = currentQty - qty;
        if (remain == 0) {
          tx.delete(posRef);
        } else {
          tx.set(
            posRef,
            {
              'qty': remain,
              // keep same avgCost
              'avgCost': avgCost,
              'symbol': symbol,
              'name': name,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        tx.update(walletRef, {'cash': cash + cost});
      }

      // add order record
      final orderRef = ordersCol.doc();
      tx.set(orderRef, {
        'companyId': companyId,
        'symbol': symbol,
        'name': name,
        'side': side,
        'qty': qty,
        'price': price,
        'total': double.parse(cost.toStringAsFixed(6)),
        'time': simDate, // simulation time
        'createdAt': FieldValue.serverTimestamp(), // server time
      });

      return {
        'orderId': orderRef.id,
        'side': side,
        'qty': qty,
        'price': price,
      };
    });
  }
}
