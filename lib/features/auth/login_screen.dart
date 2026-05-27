import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = ref.read(authControllerProvider);

      if (_isSignUp) {
        await auth.signUpWithEmail(
          _emailCtrl.text,
          _passCtrl.text,
          _nameCtrl.text,
        );
      } else {
        await auth.signInWithEmail(_emailCtrl.text, _passCtrl.text);
      }

      if (mounted) {
        final needsProfileName = await _needsProfileName();
        if (mounted) context.go(needsProfileName ? '/profile' : '/fixture');
      }
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(dynamic e) {
    final l10n = AppLocalizations.of(context)!;
    String errorMsg = e
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('[firebase_auth/', '')
        .replaceAll(']', '')
        .replaceAll('firebase_auth/', '')
        .trim();

    if (errorMsg.contains('invalid-email')) {
      errorMsg = l10n.errorEmail;
    } else if (errorMsg.contains('wrong-password') ||
        errorMsg.contains('user-not-found')) {
      errorMsg = l10n.incorrectCredentials;
    } else if (errorMsg.contains('email-already-in-use')) {
      errorMsg = l10n.emailAlreadyInUse;
    } else if (errorMsg.contains('weak-password')) {
      errorMsg = l10n.errorPassword;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.errorAuth(errorMsg)),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _needsProfileName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final displayName =
        (doc.data()?['displayName'] as String?) ?? user.displayName ?? '';
    return displayName.trim().isEmpty ||
        displayName.trim().toLowerCase() == 'anónimo' ||
        displayName.trim().toLowerCase() == 'anonimo' ||
        displayName.trim().toLowerCase() == 'anonymous';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);

    if (authState.hasValue && authState.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/fixture');
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.sports_soccer,
                    size: 72,
                    color: Color(0xFF0052CC),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.appTitle,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.loginWelcome,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.name,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.errorRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.emailHint,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.errorRequired;
                      }
                      if (!value.contains('@')) {
                        return l10n.errorEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.passwordHint,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return l10n.errorPassword;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isSignUp ? l10n.signUp : l10n.loginButton,
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(
                      _isSignUp
                          ? l10n.alreadyHaveAccount
                          : '${l10n.noAccount} ${l10n.signUp.toLowerCase()}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
