import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final createGroupProvider = FutureProvider.family<void, String>((
  ref,
  groupName,
) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw Exception('No autenticado');
  }

  // Generar código único de 6 caracteres
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  String code = List.generate(
    6,
    (_) => chars[DateTime.now().microsecondsSinceEpoch % chars.length],
  ).join();

  // Verificar unicidad
  while ((await FirebaseFirestore.instance.collection('groups').doc(code).get())
      .exists) {
    code = List.generate(
      6,
      (_) => chars[DateTime.now().microsecondsSinceEpoch % chars.length],
    ).join();
  }

  final groupId = const Uuid().v4();
  await FirebaseFirestore.instance.collection('groups').doc(code).set({
    'groupId': groupId,
    'name': groupName,
    'code': code,
    'createdBy': uid,
    'members': [uid],
    'createdAt': FieldValue.serverTimestamp(),
  });
});

final joinGroupProvider = FutureProvider.family<void, String>((
  ref,
  code,
) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw Exception('No autenticado');
  }

  final docRef = FirebaseFirestore.instance
      .collection('groups')
      .doc(code.toUpperCase());
  final doc = await docRef.get();
  if (!doc.exists) {
    throw Exception('Código inválido');
  }

  final data = doc.data()!;
  if ((data['members'] as List).contains(uid)) {
    throw Exception('Ya eres miembro de este grupo');
  }

  await docRef.update({
    'members': FieldValue.arrayUnion([uid]),
  });
});

final userGroupsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('groups')
      .where('members', arrayContains: uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList());
});
