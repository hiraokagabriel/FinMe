import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _loading    = false;
  bool _isRegister = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (_isRegister) {
      final ok = await AuthService.instance.register(username, password);
      if (!mounted) return;
      if (!ok) {
        setState(() { _loading = false; _error = 'Nome de usuário já existe.'; });
        return;
      }
      await AuthService.instance.login(username, password);
    } else {
      final ok = await AuthService.instance.login(username, password);
      if (!mounted) return;
      if (!ok) {
        setState(() { _loading = false; _error = 'Usuário ou senha incorretos.'; });
        return;
      }
    }

    if (!mounted) return;
    await ProfileService.instance.loadFromStorage();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.profilePick);
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'FinMe',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegister ? 'Criar conta' : 'Entrar',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Usuário'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    validator: (v) =>
                        (_isRegister && (v == null || v.length < 4))
                            ? 'Mínimo 4 caracteres'
                            : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 8),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isRegister ? 'Criar conta' : 'Entrar'),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => setState(() {
                      _isRegister = !_isRegister;
                      _error = null;
                    }),
                    child: Text(
                      _isRegister ? 'Já tem conta? Entrar' : 'Criar nova conta',
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
