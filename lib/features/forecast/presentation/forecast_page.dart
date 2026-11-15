import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/account.dart';
import '../domain/forecast.dart';
import 'forecast_chart.dart';
import 'forecast_events.dart';
import 'forecast_installments.dart';
import 'forecast_invoice_timeline.dart';
import 'forecast_summary.dart';

const _horizons = [3, 6, 12];

class ForecastPage extends StatelessWidget {
  const ForecastPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.ledger,
      builder: (context, _) {
        final forecast = s.ledger.forecast;
        final settings = s.settings.value;
        final ultra = settings.mode == AppMode.ultra;
        final months = settings.forecastMonths;
        final padding = MediaQuery.sizeOf(context).width < 600
            ? AppSpace.lg
            : AppSpace.xl;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Previsão',
              actions: [
                SegmentedButton<int>(
                  segments: [
                    for (final m in _horizons)
                      ButtonSegment(value: m, label: Text('${m}m')),
                  ],
                  // Horizonte fora de 3/6/12 (ex.: 9 via backup) deixa nada selecionado.
                  selected: _horizons.contains(months) ? {months} : const {},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    s.settings.update(
                      (st) => st.copyWith(forecastMonths: selection.first),
                    );
                  },
                ),
              ],
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: ListView(
                    padding: EdgeInsets.all(padding),
                    children: [
                      ForecastSummary(forecast: forecast),
                      const SizedBox(height: AppSpace.lg),
                      ForecastMonthCards(months: forecast.months),
                      const SizedBox(height: AppSpace.lg),
                      if (ultra) ...[
                        InvoiceTimelineSection(
                          items: s.ledger.invoiceTimeline,
                          accounts: s.ledger.accountsById,
                        ),
                        const SizedBox(height: AppSpace.lg),
                        InstallmentCommitmentsSection(
                          items: s.ledger.installmentCommitments,
                          cards: s.ledger.cardsById,
                        ),
                        const SizedBox(height: AppSpace.lg),
                        SectionCard(
                          title: 'Saldo diário',
                          child: ForecastDailyChart(daily: forecast.daily),
                        ),
                        const SizedBox(height: AppSpace.lg),
                        SectionCard(
                          title: 'Eventos',
                          child: ForecastEventsFilter(
                            events: forecast.events,
                            accounts: s.ledger.accountsById,
                          ),
                        ),
                      ] else
                        _NextEvents(
                          events: forecast.events,
                          accounts: s.ledger.accountsById,
                        ),
                    ],
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

/// Modo Simples: próximos 10 eventos, sem filtros.
class _NextEvents extends StatelessWidget {
  const _NextEvents({required this.events, required this.accounts});

  final List<ForecastEvent> events;
  final Map<String, Account> accounts;

  @override
  Widget build(BuildContext context) {
    final next = events.take(10).toList();
    return SectionCard(
      title: 'Próximos eventos',
      child: next.isEmpty
          ? const EmptyState(
              icon: Icons.event_available,
              message: 'Nenhum evento previsto',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in next)
                  ForecastEventRow(
                    event: e,
                    accountName: accountNameOf(accounts, e.accountId),
                  ),
              ],
            ),
    );
  }
}
