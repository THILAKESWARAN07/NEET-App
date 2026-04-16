import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

enum _AuthMode { signIn, register }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    if (_mode == _AuthMode.register) {
      await notifier.registerWithEmailPassword(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
      );
    } else {
      await notifier.signInWithEmailPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 48),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.school_rounded,
                    size: 80,
                    color: Color(0xFF4F46E5), // Primary
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'NEET Prep Pro',
                    style: Theme.of(context).textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Master Physics, Chemistry, and Biology to achieve your dream medical rank.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  SegmentedButton<_AuthMode>(
                    segments: const [
                      ButtonSegment<_AuthMode>(
                        value: _AuthMode.signIn,
                        label: Text('Sign in'),
                        icon: Icon(Icons.login),
                      ),
                      ButtonSegment<_AuthMode>(
                        value: _AuthMode.register,
                        label: Text('Create account'),
                        icon: Icon(Icons.person_add_alt_1),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: state.isLoading
                        ? null
                        : (selection) {
                            setState(() => _mode = selection.first);
                          },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email address'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_mode == _AuthMode.register) ...[
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (!state.isLoading) {
                        _submitEmailAuth();
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: state.isLoading ? null : _submitEmailAuth,
                    child: state.isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _mode == _AuthMode.register ? 'Create account' : 'Sign in',
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: state.isLoading
                        ? null
                        : () => ref.read(authProvider.notifier).signInWithGoogle(),
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with Google', style: TextStyle(fontSize: 18)),
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'By signing in, you agree to our Terms and Privacy Policy.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
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
