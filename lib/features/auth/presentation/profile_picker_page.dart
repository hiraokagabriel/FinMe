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
  final _nameCtrl        = TextEditingController();
  bool  _creating        = false;
  String _selectedEmoji  = '\uD83D\uDC64';

  static const _emojis = ['\uD83D\uDC64','\uD83D\uDCBC','\uD83C\uDFE0','\uD83D\uDCB0','\uD83C\uDF1F','\uD83D\uDCDA','\uD83D\uDCCA'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _select(ProfileModel profile) async {
    final loginId = AuthService.instance.activeLoginId!;
    await AuthService.instance.switchProfile(profile.id);
    await ProfileService.instance.switchTo(loginId, profile.id);
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
    final scheme   = theme.colorScheme;
    final profiles = AuthService.instance.profilesForActiveLogin;
    final atLimit  = profiles.length >= AuthService.maxProfilesPerLogin;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Selecionar Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
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
            if (profiles.isNotEmpty) ...[
              Text(
                'Seus perfis',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...profiles.map((p) => _ProfileTile(
                profile: p,
                onTap: () => _select(p),
              )),
              const SizedBox(height: 24),
            ],

            if (!atLimit) ...[
              Text(
                'Novo perfil',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                children: _emojis.map((e) => GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: e == _selectedEmoji
                          ? scheme.primary.withOpacity(0.15)
                          : scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: e == _selectedEmoji
                            ? scheme.primary
                            : AppColors.divider,
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
                      decoration: const InputDecoration(
                        hintText: 'Nome do perfil',
                      ),
                      onSubmitted: (_) => _createProfile(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _creating ? null : _createProfile,
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
                style: theme.textTheme.bodySmall,
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

  const _ProfileTile({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Row(
            children: [
              Text(profile.avatarEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  profile.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: scheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
