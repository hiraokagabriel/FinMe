import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/profile_model.dart';

class ProfilePickerPage extends StatefulWidget {
  const ProfilePickerPage({super.key});

  @override
  State<ProfilePickerPage> createState() => _ProfilePickerPageState();
}

class _ProfilePickerPageState extends State<ProfilePickerPage> {
  final _nameCtrl  = TextEditingController();
  bool  _creating  = false;
  String _selectedEmoji = '👤';

  static const _emojis = ['👤', '💼', '🏠', '💰', '🌟', '📚', '📊'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _select(ProfileModel profile) async {
    await AuthService.instance.switchProfile(profile.id);
    await ProfileService.instance.switchTo(
      AuthService.instance.activeLoginId!,
      profile.id,
    );
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.dashboard);
  }

  Future<void> _createProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    final profile = await AuthService.instance.createProfile(name, _selectedEmoji);
    if (!mounted) return;
    setState(() => _creating = false);
    if (profile != null) {
      _nameCtrl.clear();
      await _select(profile);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final colors   = theme.extension<AppColors>()!;
    final profiles = AuthService.instance.profilesForActiveLogin;
    final atLimit  = profiles.length >= AuthService.maxProfilesPerLogin;

    return Scaffold(
      backgroundColor: colors.colorBackground,
      appBar: AppBar(
        backgroundColor: colors.colorSurface,
        elevation: 0,
        title: Text(
          'Selecionar Perfil',
          style: TextStyle(
            color: colors.colorTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_outlined, color: colors.colorTextSecondary),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Lista de perfis existentes
            if (profiles.isNotEmpty) ...[
              Text(
                'Seus perfis',
                style: TextStyle(
                  color: colors.colorTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...profiles.map((p) => _ProfileTile(
                profile: p,
                onTap: () => _select(p),
                colors: colors,
              )),
              const SizedBox(height: 24),
            ],

            // Criar novo perfil
            if (!atLimit) ...[
              Text(
                'Novo perfil',
                style: TextStyle(
                  color: colors.colorTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Seletor de emoji
              Wrap(
                spacing: 8,
                children: _emojis.map((e) => GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: e == _selectedEmoji
                          ? colors.colorPrimary.withOpacity(0.15)
                          : colors.colorSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: e == _selectedEmoji
                            ? colors.colorPrimary
                            : colors.colorBorder,
                        width: e == _selectedEmoji ? 1.5 : 1,
                      ),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Nome do perfil',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      ),
                      onSubmitted: (_) => _createProfile(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _creating ? null : _createProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.colorPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _creating
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                        : const Text('Criar'),
                  ),
                ],
              ),
            ] else
              Text(
                'Limite de ${AuthService.maxProfilesPerLogin} perfis atingido.',
                style: TextStyle(color: colors.colorTextSecondary, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onTap;
  final AppColors    colors;

  const _ProfileTile({
    required this.profile,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.colorSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.colorBorder, width: 1),
          ),
          child: Row(
            children: [
              Text(profile.avatarEmoji,
                  style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  profile.name,
                  style: TextStyle(
                    color: colors.colorTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: colors.colorTextSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
