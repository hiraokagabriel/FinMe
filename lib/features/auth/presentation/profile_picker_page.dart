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
  bool _busy = false;

  static const _emojis = [
    '\uD83D\uDC64', '\uD83D\uDCBC', '\uD83C\uDFE0', '\uD83D\uDCB0',
    '\uD83C\uDF1F', '\uD83D\uDCDA', '\uD83D\uDCCA', '\uD83C\uDFAE',
    '\uD83D\uDC36', '\uD83C\uDF3B', '\uD83D\uDE80', '\uD83C\uDFA8',
  ];

  Future<void> _select(ProfileModel profile) async {
    if (_busy) return;
    setState(() => _busy = true);
    final loginId = AuthService.instance.activeLoginId!;
    await AuthService.instance.switchProfile(profile.id);
    await ProfileService.instance.switchTo(loginId, profile.id);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.dashboard);
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Você precisará fazer login novamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Sair')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.login);
  }

  Future<void> _showCreateSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card * 2)),
      ),
      builder: (ctx) => _ProfileFormSheet(
        title: 'Novo perfil',
        emojis: _emojis,
        onSave: (name, emoji) async {
          final profile = await AuthService.instance.createProfile(name, emoji);
          if (!mounted) return;
          Navigator.pop(ctx);
          if (profile != null) await _select(profile);
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showEditSheet(ProfileModel profile) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card * 2)),
      ),
      builder: (ctx) => _ProfileFormSheet(
        title: 'Editar perfil',
        emojis: _emojis,
        initialName: profile.name,
        initialEmoji: profile.avatarEmoji,
        showDelete: AuthService.instance.profilesForActiveLogin.length > 1,
        onSave: (name, emoji) async {
          await AuthService.instance.updateProfile(profile.id, name: name, avatarEmoji: emoji);
          if (!mounted) return;
          Navigator.pop(ctx);
          setState(() {});
        },
        onDelete: () async {
          Navigator.pop(ctx);
          await _confirmDelete(profile);
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete(ProfileModel profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir perfil?'),
        content: Text('"${profile.name}" e todos os dados vinculados serão removidos permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AuthService.instance.deleteProfile(profile.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final scheme   = theme.colorScheme;
    final auth     = AuthService.instance;
    final profiles = auth.profilesForActiveLogin;
    final atLimit  = profiles.length >= AuthService.maxProfilesPerLogin;
    final username = auth.activeUsername ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Perfis'),
            if (username.isNotEmpty)
              Text(
                '@$username',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sair da conta',
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Lista de perfis ──────────────────────────────────────────
          ...profiles.map((p) {
            final isActive = p.id == auth.activeProfileId;
            return _ProfileTile(
              profile:  p,
              isActive: isActive,
              onTap:    () => _select(p),
              onEdit:   () => _showEditSheet(p),
            );
          }),

          const SizedBox(height: 8),

          // ── Adicionar perfil ─────────────────────────────────────────
          if (!atLimit)
            _AddProfileTile(onTap: _showCreateSheet)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'Limite de ${AuthService.maxProfilesPerLogin} perfis atingido.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Tile de perfil
// ────────────────────────────────────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  final ProfileModel profile;
  final bool         isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: isActive
                    ? scheme.primary.withValues(alpha: 0.4)
                    : AppColors.divider,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(profile.avatarEmoji,
                    style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isActive)
                        Text(
                          'Ativo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                // botão editar
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: scheme.onSurfaceVariant),
                  tooltip: 'Editar',
                  onPressed: onEdit,
                ),
                // chevron selecionar
                Icon(Icons.chevron_right,
                    color: scheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Tile "+ Adicionar perfil"
// ────────────────────────────────────────────────────────────────────────────
class _AddProfileTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddProfileTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: AppColors.divider,
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline,
                  size: 26, color: scheme.primary),
              const SizedBox(width: 12),
              Text(
                'Adicionar perfil',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Bottom sheet de criação/edição
// ────────────────────────────────────────────────────────────────────────────
class _ProfileFormSheet extends StatefulWidget {
  final String title;
  final List<String> emojis;
  final String? initialName;
  final String? initialEmoji;
  final bool showDelete;
  final Future<void> Function(String name, String emoji) onSave;
  final VoidCallback? onDelete;

  const _ProfileFormSheet({
    required this.title,
    required this.emojis,
    required this.onSave,
    this.initialName,
    this.initialEmoji,
    this.showDelete = false,
    this.onDelete,
  });

  @override
  State<_ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends State<_ProfileFormSheet> {
  late final TextEditingController _nameCtrl;
  late String _emoji;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _emoji    = widget.initialEmoji ?? widget.emojis.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(name, _emoji);
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header
          Row(
            children: [
              Expanded(
                child: Text(widget.title,
                    style: AppText.screenTitle),
              ),
              if (widget.showDelete && widget.onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: AppColors.danger),
                  tooltip: 'Excluir perfil',
                  onPressed: widget.onDelete,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // emoji picker
          Text('Avatar', style: AppText.sectionLabel),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.emojis.map((e) => GestureDetector(
              onTap: () => setState(() => _emoji = e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: e == _emoji
                      ? scheme.primary.withValues(alpha: 0.12)
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: e == _emoji
                        ? scheme.primary
                        : AppColors.divider,
                    width: e == _emoji ? 1.5 : 1,
                  ),
                ),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),

          // nome
          Text('Nome', style: AppText.sectionLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ex: Pessoal, Empresa…'),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),

          // botão salvar
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(widget.initialName != null ? 'Salvar' : 'Criar'),
          ),
        ],
      ),
    );
  }
}
