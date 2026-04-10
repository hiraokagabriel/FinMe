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
      // Autentica após registro
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

    // Abre boxes e inicializa repositórios para o perfil ativo
    await ProfileService.instance.loadFromStorage();

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.profilePick);
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final colors  = theme.extension<AppColors>()!;
    final isDark  = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.colorBackground,
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
                  // Logo / Título
                  Text(
                    'FinMe',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colors.colorPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegister ? 'Criar conta' : 'Entrar',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.colorTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Campo usuário
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Usuário',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Campo senha
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (v) =>
                        (_isRegister && (v == null || v.length < 4))
                            ? 'Mínimo 4 caracteres'
                            : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 8),

                  // Erro
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: colors.colorDanger,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  // Botão principal
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.colorPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isRegister ? 'Criar conta' : 'Entrar',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle login / registro
                  TextButton(
                    onPressed: () => setState(() {
                      _isRegister = !_isRegister;
                      _error = null;
                    }),
                    child: Text(
                      _isRegister
                          ? 'Já tem conta? Entrar'
                          : 'Criar nova conta',
                      style: TextStyle(color: colors.colorPrimary),
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
