import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PortfolioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. SAVE SCENARIO
  Future<void> saveScenario({
    required String name,
    required String location,
    required Map<String, dynamic> metrics, // roi, netProfit, totalCost
    required Map<String, dynamic> fullData, // The inputs (propertyData)
    required Map<String, dynamic> selections, // The selections
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    await _db.collection('scenarios').add({
      'userId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'name': name,
      'location': location,
      'metrics': metrics,
      'data': fullData, // Saves the full input state
      'selections': selections,
    });
  }

  // 2. GET STREAM (Real-time List)
  Stream<QuerySnapshot> getUserScenarios() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('scenarios')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  // 3. DELETE
  Future<void> deleteScenario(String docId) async {
    await _db.collection('scenarios').doc(docId).delete();
  }
}
