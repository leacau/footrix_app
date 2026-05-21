import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🔥 Stream del estado de autenticación
final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// 🔥 Controller para acciones de auth
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController();
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final token = await user.getIdTokenResult(true);
  return token.claims?['admin'] == true;
});

class AuthController {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Email/Password - Login
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ✅ Email/Password - Registro (con UID consistente)
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    // 1. Crear usuario en Firebase Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // 2. Obtener el UID generado por Auth
    final user = cred.user;
    if (user == null) throw Exception('No se pudo crear el usuario');

    final uid = user.uid;

    // 3. Actualizar perfil en Auth
    await user.updateDisplayName(displayName.trim());

    // 4. ✅ CREAR documento en Firestore USANDO EL MISMO UID COMO ID
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email.trim(),
      'displayName': displayName.trim(),
      'photoURL': user.photoURL,
      'totalPoints': 0,
      'streakTrivia': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'country': null,
      'privateGroups': [],
    });

    return cred;
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Obtener datos del usuario desde Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // Actualizar último login
  Future<void> updateLastLogin(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
