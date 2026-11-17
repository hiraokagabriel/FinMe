import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/seed.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/year_month.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../importing/domain/merchant_dictionary.dart';
import '../../profiles/presentation/profile_section.dart';

const _jsonGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
const _csvGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pad = MediaQuery.sizeOf(context).width < 600
        ? AppSpace.lg
        : AppSpace.xl;
    return ListenableBuilder(
      listenable: s.settings,
      builder: (context, _) {
        final settings = s.settings.value;
        final ultra = settings.mode == AppMode.ultra;
        return Column(
          children: [
            const PageHeader(title: 'Ajustes'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ProfileSection(),
                        _AppearanceCard(services: s, settings: settings),
                        if (ultra) ...[
                          const SizedBox(height: AppSpace.lg),
                          _ForecastCard(services: s, settings: settings),
                        ],
                        const SizedBox(height: AppSpace.lg),
                        _DataCard(services: s, ultra: ultra),
                        const SizedBox(height: AppSpace.xl),
                        Text(
                          'FinMe v2 · dados locais',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.services, required this.settings});

  final AppServices services;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: context.colors.textSecondary,
    );
    return SectionCard(
      title: 'Aparência',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Modo', style: textTheme.titleSmall),
          const SizedBox(height: AppSpace.sm),
          SegmentedButton<AppMode>(
            segments: const [
              ButtonSegment(value: AppMode.simple, label: Text('Simples')),
              ButtonSegment(value: AppMode.ultra, label: Text('Ultra')),
            ],
            selected: {settings.mode},
            onSelectionChanged: (sel) =>
                services.settings.update((c) => c.copyWith(mode: sel.first)),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            settings.mode == AppMode.ultra
                ? 'Visão detalhada: limites, categorias, filtros e provisionados.'
                : 'Visão enxuta: saldo, faturas e próximos vencimentos.',
            style: secondary,
          ),
          const SizedBox(height: AppSpace.lg),
          Text('Tema', style: textTheme.titleSmall),
          const SizedBox(height: AppSpace.sm),
          SegmentedButton<ThemePreference>(
            segments: const [
              ButtonSegment(
                value: ThemePreference.system,
                label: Text('Sistema'),
              ),
              ButtonSegment(value: ThemePreference.light, label: Text('Claro')),
              ButtonSegment(value: ThemePreference.dark, label: Text('Escuro')),
            ],
            selected: {settings.theme},
            onSelectionChanged: (sel) =>
                services.settings.update((c) => c.copyWith(theme: sel.first)),
          ),
          const SizedBox(height: AppSpace.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ocultar valores'),
            subtitle: Text(
              'Mostra "R\$ ••••" no lugar dos valores',
              style: secondary,
            ),
            value: settings.hideValues,
            onChanged: (on) =>
                services.settings.update((c) => c.copyWith(hideValues: on)),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.services, required this.settings});

  final AppServices services;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final months = settings.forecastMonths;
    return SectionCard(
      title: 'Previsão',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Horizonte de previsão',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                '$months meses',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            min: AppSettings.minForecastMonths.toDouble(),
            max: AppSettings.maxForecastMonths.toDouble(),
            divisions:
                AppSettings.maxForecastMonths - AppSettings.minForecastMonths,
            value: months.toDouble(),
            label: '$months meses',
            onChanged: (v) => services.settings.update(
              (c) => c.copyWith(forecastMonths: v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataCard extends StatefulWidget {
  const _DataCard({required this.services, required this.ultra});

  final AppServices services;
  final bool ultra;

  @override
  State<_DataCard> createState() => _DataCardState();
}

class _DataCardState extends State<_DataCard> {
  YearMonth? _csvMonth;

  AppServices get _s => widget.services;

  void _snack(ScaffoldMessengerState messenger, String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final location = await getSaveLocation(
        suggestedName: 'finme-backup-${dateKey(_s.clock())}.json',
        acceptedTypeGroups: const [_jsonGroup],
      );
      if (location == null) {
        return;
      }
      await File(location.path).writeAsString(BackupService.exportJson(_s));
      _snack(messenger, 'Backup exportado.');
    } catch (_) {
      _snack(messenger, 'Não foi possível exportar o backup.');
    }
  }

  Future<void> _importBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await openFile(acceptedTypeGroups: const [_jsonGroup]);
      if (file == null || !mounted) {
        return;
      }
      final ok = await confirmDialog(
        context,
        title: 'Importar backup?',
        message:
            'Todos os dados atuais serão substituídos pelo conteúdo do arquivo.',
        confirmLabel: 'Importar',
        destructive: true,
      );
      if (!ok || !mounted) {
        return;
      }
      await BackupService.importJson(_s, await file.readAsString());
      _snack(messenger, 'Backup importado.');
    } on FormatException {
      _snack(messenger, 'Arquivo de backup inválido.');
    } catch (_) {
      _snack(messenger, 'Não foi possível importar o backup.');
    }
  }

  Future<void> _exportCsv(YearMonth month) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final location = await getSaveLocation(
        suggestedName: 'finme-${month.key}.csv',
        acceptedTypeGroups: const [_csvGroup],
      );
      if (location == null) {
        return;
      }
      // BOM UTF-8 para o Excel reconhecer acentos.
      final csv = BackupService.transactionsCsv(_s, month: month);
      await File(location.path).writeAsString('﻿$csv');
      _snack(messenger, 'CSV exportado.');
    } catch (_) {
      _snack(messenger, 'Não foi possível exportar o CSV.');
    }
  }

  Future<void> _eraseAll() async {
    final ok = await confirmDialog(
      context,
      title: 'Apagar todos os dados?',
      message:
          'Contas, cartões, lançamentos, recorrências, metas, ativos, dívidas, regras e perfis de importação serão removidos. O dicionário volta ao padrão. Esta ação não pode ser desfeita.',
      confirmLabel: 'Apagar',
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Sem sync: a gravação assíncrona da dívida poderia ressuscitar pagamentos apagados (SPEC §9.12).
      await _s.debtSync.suspendDuring(() async {
        await _s.accounts.replaceAll(const []);
        await _s.cards.replaceAll(const []);
        await _s.transactions.replaceAll(const []);
        await _s.recurring.replaceAll(const []);
        await _s.goals.replaceAll(const []);
        await _s.assets.replaceAll(const []);
        await _s.debts.replaceAll(const []);
        await _s.importBatches.replaceAll(const []);
        await _s.categories.replaceAll(defaultCategories());
        await _s.rules.replaceAll(const []);
        await _s.importProfiles.replaceAll(const []);
        await _s.dictionary.replaceAll(defaultDictionary());
      });
      // Volta ao onboarding: o shell some quando onboardingDone for false.
      await _s.settings.update((c) => c.copyWith(onboardingDone: false));
    } catch (_) {
      _snack(messenger, 'Não foi possível apagar os dados.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = _csvMonth ?? YearMonth.fromDate(_s.clock());
    return SectionCard(
      title: 'Dados',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _exportBackup,
                icon: const Icon(Icons.save_alt),
                label: const Text('Exportar backup (JSON)'),
              ),
              if (widget.ultra)
                OutlinedButton.icon(
                  onPressed: _importBackup,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Importar backup'),
                ),
            ],
          ),
          if (widget.ultra) ...[
            const Divider(height: AppSpace.xl),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpace.md,
              runSpacing: AppSpace.sm,
              children: [
                MonthSelector(
                  value: month,
                  onChanged: (m) => setState(() => _csvMonth = m),
                ),
                FilledButton.icon(
                  onPressed: () => _exportCsv(month),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Exportar CSV do mês'),
                ),
              ],
            ),
            const Divider(height: AppSpace.xl),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.danger,
                ),
                onPressed: _eraseAll,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Apagar todos os dados'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
