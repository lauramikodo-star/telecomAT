import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ndController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _login() async {
    final state = context.read<AppState>();
    await state.login(
      _ndController.text,
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final loginResult = state.loginResult;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ndController,
            decoration: const InputDecoration(
              labelText: 'Phone Number (ND)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: state.loading ? null : _login,
            child: state.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Login'),
          ),
          const SizedBox(height: 24),
          if (loginResult != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loginResult['code'] == 0 ? 'Login Successful' : 'Login Failed',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (loginResult['code'] == 0)
                      ...[
                        Text('Name: ${loginResult['data']['nom']} ${loginResult['data']['prenom']}'),
                        Text('Email: ${loginResult['data']['email']}'),
                        Text('ND: ${loginResult['data']['nd']}'),
                        Text('Type: ${loginResult['data']['type']}'),
                        const SizedBox(height: 12),
                        Text(
                          'Token: ${loginResult['authorisation']['token']}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ]
                    else
                      Text(loginResult['error'] ?? loginResult['message'] ?? 'An unknown error occurred.'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
