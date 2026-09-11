import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/constants.dart';
import '../models/radar.dart';

/// Reads and writes the `radars` and `app_config` collections.
///
/// [enabled] is false whenever `Firebase.initializeApp()` failed at startup
/// (missing `google-services.json` / `GoogleService-Info.plist`, or no
/// network). Callers treat a thrown error as "fall back to the bundled JSON".
class FirestoreService {
  FirestoreService({required this.enabled, FirebaseFirestore? firestore})
      : _injected = firestore;

  final bool enabled;
  final FirebaseFirestore? _injected;

  static const Duration _timeout = Duration(seconds: 10);

  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  Future<List<Radar>> fetchRadars() async {
    if (!enabled) {
      throw StateError('Firebase nije inicijalizovan.');
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection(AppConstants.radarsCollection)
        .get()
        .timeout(_timeout);

    if (snapshot.docs.isEmpty) {
      throw StateError('Kolekcija "radars" je prazna.');
    }

    final List<Radar> radars =
        snapshot.docs.map(Radar.fromFirestore).toList(growable: false)
          ..sort((Radar a, Radar b) => a.id.compareTo(b.id));
    return radars;
  }

  /// Server-side default alert radius; `null` when the document is absent.
  Future<double?> fetchDefaultRadius() async {
    if (!enabled) return null;
    final DocumentSnapshot<Map<String, dynamic>> doc = await _db
        .collection(AppConstants.appConfigCollection)
        .doc(AppConstants.appConfigDocumentId)
        .get()
        .timeout(_timeout);
    return (doc.data()?['default_radius_meters'] as num?)?.toDouble();
  }

  /// Writes every radar plus the app config in a single batch.
  Future<int> seed(List<Radar> radars) async {
    if (!enabled) {
      throw StateError('Firebase nije inicijalizovan.');
    }
    final WriteBatch batch = _db.batch();
    final CollectionReference<Map<String, dynamic>> collection =
        _db.collection(AppConstants.radarsCollection);

    for (final Radar radar in radars) {
      batch.set(collection.doc(radar.id), radar.toJson());
    }

    batch.set(
      _db
          .collection(AppConstants.appConfigCollection)
          .doc(AppConstants.appConfigDocumentId),
      <String, dynamic>{
        'default_radius_meters': AppConstants.defaultRadiusMeters,
        'app_version': AppConstants.appVersion,
        'radar_count': radars.length,
        'data_source': AppConstants.dataSource,
      },
    );

    await batch.commit();
    return radars.length;
  }
}
