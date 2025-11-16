import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthForm extends StatefulWidget {
  const AuthForm({super.key});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  var _isLogin = true;
  var _loading = false;
  var _email = '';
  var _password = '';
  var _fullName = '';
  UserRole _selectedRole = UserRole.patient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('M2B Auth')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isLogin)
                      TextFormField(
                        key: const ValueKey('name'),
                        decoration: const InputDecoration(labelText: 'Full name'),
                        onSaved: (value) => _fullName = value!.trim(),
                        validator: (value) =>
                            (value == null || value.trim().length < 3)
                                ? 'Enter your name'
                                : null,
                      ),
                    TextFormField(
                      key: const ValueKey('email'),
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      onSaved: (value) => _email = value!.trim(),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      key: const ValueKey('password'),
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      onSaved: (value) => _password = value!.trim(),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Min 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (!_isLogin)
                      DropdownButtonFormField<UserRole>(
                        initialValue: _selectedRole,
                        items: const [
                          DropdownMenuItem(
                            value: UserRole.patient,
                            child: Text('Patient'),
                          ),
                          DropdownMenuItem(
                            value: UserRole.doctor,
                            child: Text('Doctor'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedRole = value);
                          }
                        },
                        decoration:
                            const InputDecoration(labelText: 'Sign up as'),
                      ),
                    const SizedBox(height: 24),
                    _loading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _submit,
                            child: Text(_isLogin ? 'Sign in' : 'Create account'),
                          ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text(_isLogin
                          ? 'Need an account? Sign up'
                          : 'Already have an account? Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
      } else {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        final uid = credential.user!.uid;
        final roleName =
            _selectedRole == UserRole.patient ? 'patient' : 'doctor';

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'role': roleName,
          'email': _email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final data = {
          'email': _email,
          'fullName': _fullName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final collection =
            _selectedRole == UserRole.patient ? 'patients' : 'doctors';
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(uid)
            .set(data);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Authentication failed');
    } catch (_) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

enum UserRole { patient, doctor }
