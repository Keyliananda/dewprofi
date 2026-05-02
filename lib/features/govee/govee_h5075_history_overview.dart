import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'govee_h5075_gatt_probe.dart';
import 'govee_h5075_history_view_model.dart';

class GoveeH5075HistoryOverviewPage extends StatefulWidget {
  const GoveeH5075HistoryOverviewPage({super.key, required this.snapshot});

  final GoveeH5075GattProbeSnapshot snapshot;

  @override
  State<GoveeH5075HistoryOverviewPage> createState() =>
      _GoveeH5075HistoryOverviewPageState();
}

class _GoveeH5075HistoryOverviewPageState
    extends State<GoveeH5075HistoryOverviewPage> {
  GoveeH5075HistoryDisplayPeriod _period = GoveeH5075HistoryDisplayPeriod.month;
  DateTime? _anchor;

  @override
  Widget build(BuildContext context) {
    final latestModel = GoveeH5075HistoryViewModel.fromSnapshot(
      widget.snapshot,
      period: _period,
    );
    final latestAnchor = latestModel.rangeEnd;
    final anchor = _anchor ?? latestAnchor;
    final model = GoveeH5075HistoryViewModel.fromSnapshot(
      widget.snapshot,
      period: _period,
      anchor: anchor,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEEF6FD),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HistoryHeader(
            model: model,
            period: _period,
            onPeriodChanged: (period) {
              setState(() {
                _period = period;
                _anchor = null;
              });
            },
          ),
          _HistorySheet(
            model: model,
            canGoForward: anchor.isBefore(latestAnchor),
            onPrevious: () => setState(() {
              _anchor = anchor.subtract(_period.duration);
            }),
            onNext: () => setState(() {
              final nextAnchor = anchor.add(_period.duration);
              _anchor = nextAnchor.isAfter(latestAnchor)
                  ? latestAnchor
                  : nextAnchor;
            }),
          ),
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.model,
    required this.period,
    required this.onPeriodChanged,
  });

  final GoveeH5075HistoryViewModel model;
  final GoveeH5075HistoryDisplayPeriod period;
  final ValueChanged<GoveeH5075HistoryDisplayPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final temperature = model.currentTemperatureCelsius;
    final humidity = model.currentRelativeHumidityPercent;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0AA8E9), Color(0xFF0877F6)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topPadding + 18, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _HeaderCircleButton(
                  tooltip: 'Zurueck',
                  icon: Icons.chevron_left,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        model.deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bluetooth,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              model.hasVisibleHistory
                                  ? 'History geladen'
                                  : 'Keine History',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _HeaderCircleButton(
                  tooltip: 'Diagramm',
                  icon: Icons.bar_chart,
                  onPressed: () => _showHeaderSheet(context),
                ),
                const SizedBox(width: 10),
                _HeaderCircleButton(
                  tooltip: 'Einstellungen',
                  icon: Icons.settings_outlined,
                  onPressed: () => _showHeaderSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 56),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LiveMetric(
                    value: temperature,
                    unit: '°C',
                    label: 'Temperatur',
                    icon: Icons.thermostat,
                  ),
                ),
                const SizedBox(width: 26),
                Expanded(
                  child: _LiveMetric(
                    value: humidity,
                    unit: '%',
                    label: 'Relative Luftfeuchtigkeit',
                    icon: Icons.water_drop_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Letzte Aktualisierung ${_formatDateTime(model.lastUpdatedAt)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 58),
            _PeriodTabs(period: period, onChanged: onPeriodChanged),
          ],
        ),
      ),
    );
  }

  void _showHeaderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Wrap(
          runSpacing: 14,
          children: [
            _CoverageTile(label: 'Sensor', value: model.deviceName),
            _CoverageTile(
              label: 'Akku',
              value: model.batteryPercent == null
                  ? '-'
                  : '${model.batteryPercent}%',
            ),
            _CoverageTile(
              label: 'Abdeckung',
              value:
                  '${_formatNumber(model.coverage.coveragePercent, decimals: 1)}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({
    required this.model,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final GoveeH5075HistoryViewModel model;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEEF6FD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChartControlRow(
              coverage: model.coverage,
              onPrevious: onPrevious,
              onNext: canGoForward ? onNext : null,
            ),
            const SizedBox(height: 18),
            _HistoryMetricCard(
              key: const ValueKey('govee-history-temperature-card'),
              chart: model.temperatureChart,
              lineColor: const Color(0xFF08A7E7),
            ),
            const SizedBox(height: 24),
            _HistoryMetricCard(
              key: const ValueKey('govee-history-humidity-card'),
              chart: model.humidityChart,
              lineColor: const Color(0xFF14B8A6),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 52,
        height: 52,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 30),
          style: IconButton.styleFrom(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.48)),
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  const _LiveMetric({
    required this.value,
    required this.unit,
    required this.label,
    required this.icon,
  });

  final double? value;
  final String unit;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value == null ? '-' : _formatNumber(value!, decimals: 1),
                  style: textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 68,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                unit,
                style: textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.period, required this.onChanged});

  final GoveeH5075HistoryDisplayPeriod period;
  final ValueChanged<GoveeH5075HistoryDisplayPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF066EE5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            for (final item in GoveeH5075HistoryDisplayPeriod.values)
              Expanded(
                child: _PeriodTabButton(
                  key: ValueKey('govee-history-period-${item.name}'),
                  item: item,
                  selected: item == period,
                  onPressed: () => onChanged(item),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTabButton extends StatelessWidget {
  const _PeriodTabButton({
    super.key,
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final GoveeH5075HistoryDisplayPeriod item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: TextButton(
        onPressed: selected ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected ? const Color(0xFF0BA6E8) : Colors.white,
          disabledForegroundColor: const Color(0xFF0BA6E8),
          backgroundColor: selected ? Colors.white : Colors.transparent,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            item.label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _ChartControlRow extends StatelessWidget {
  const _ChartControlRow({
    required this.coverage,
    required this.onPrevious,
    required this.onNext,
  });

  final GoveeH5075HistoryCoverage coverage;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SheetSquareButton(
          tooltip: 'Vorheriger Zeitraum',
          icon: Icons.chevron_left,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _showCoverageSheet(context, coverage),
            icon: const Icon(Icons.tune),
            label: Text(
              'Diagramm bearbeiten',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF303238),
            ),
          ),
        ),
        const SizedBox(width: 14),
        _SheetSquareButton(
          tooltip: 'Naechster Zeitraum',
          icon: Icons.chevron_right,
          onPressed: onNext,
        ),
      ],
    );
  }

  void _showCoverageSheet(
    BuildContext context,
    GoveeH5075HistoryCoverage coverage,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Wrap(
          runSpacing: 14,
          children: [
            _CoverageTile(
              label: 'Abdeckung',
              value: '${_formatNumber(coverage.coveragePercent, decimals: 1)}%',
            ),
            _CoverageTile(
              label: 'Records',
              value: '${coverage.uniqueRecords}/${coverage.expectedMinutes}',
            ),
            _CoverageTile(
              label: 'Fehlend',
              value: '${coverage.missingRecords}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSquareButton extends StatelessWidget {
  const _SheetSquareButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 60,
        height: 60,
        child: IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon, size: 32),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.55),
            foregroundColor: const Color(0xFF7A7F86),
            disabledForegroundColor: const Color(0x667A7F86),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HistoryMetricCard extends StatefulWidget {
  const _HistoryMetricCard({
    super.key,
    required this.chart,
    required this.lineColor,
  });

  final GoveeH5075HistoryMetricChart chart;
  final Color lineColor;

  @override
  State<_HistoryMetricCard> createState() => _HistoryMetricCardState();
}

class _HistoryMetricCardState extends State<_HistoryMetricCard> {
  final _scrollController = ScrollController();
  GoveeH5075HistoryChartPoint? _selectedPoint;
  double _horizontalScale = 1;
  double _scaleGestureStartScale = 1;

  String get _chartKeySuffix =>
      widget.chart.title == 'Temperatur' ? 'temperature' : 'humidity';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _HistoryMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chart != widget.chart) {
      _selectedPoint = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final selectedPoint = _selectedPoint;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 88),
                Expanded(
                  child: Text(
                    chart.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF303238),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  width: 88,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ChartIconButton(
                        key: ValueKey(
                          'govee-history-$_chartKeySuffix-zoom-out-button',
                        ),
                        tooltip: 'Verkleinern',
                        icon: Icons.remove,
                        onPressed: _horizontalScale <= 1.01
                            ? null
                            : () => _zoomBy(0.8),
                      ),
                      _ChartIconButton(
                        key: ValueKey(
                          'govee-history-$_chartKeySuffix-zoom-in-button',
                        ),
                        tooltip: 'Vergroessern',
                        icon: Icons.add,
                        onPressed: _horizontalScale >= 4
                            ? null
                            : () => _zoomBy(1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 255,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatsColumn(chart: chart),
                  const SizedBox(width: 14),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chartWidth = math.max(
                          constraints.maxWidth,
                          constraints.maxWidth * _horizontalScale,
                        );
                        final size = Size(chartWidth, constraints.maxHeight);
                        return Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: _horizontalScale > 1.01,
                          child: SingleChildScrollView(
                            key: ValueKey(
                              'govee-history-$_chartKeySuffix-scroll',
                            ),
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: chartWidth,
                              height: constraints.maxHeight,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) =>
                                    _selectPoint(details.localPosition, size),
                                onScaleStart: (_) =>
                                    _scaleGestureStartScale = _horizontalScale,
                                onScaleUpdate: (details) =>
                                    _handleScaleUpdate(details),
                                child: CustomPaint(
                                  key: ValueKey(
                                    chart.title == 'Temperatur'
                                        ? 'govee-history-temperature-chart'
                                        : 'govee-history-humidity-chart',
                                  ),
                                  painter: _HistoryLineChartPainter(
                                    chart: chart,
                                    lineColor: widget.lineColor,
                                    selectedPoint: selectedPoint,
                                    textStyle:
                                        Theme.of(
                                          context,
                                        ).textTheme.labelSmall ??
                                        const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (selectedPoint == null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDateTimeShort(chart.rangeStart),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF303238),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatDateTimeShort(chart.rangeEnd),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF303238),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                '${_formatDateTimeShort(selectedPoint.observedAt)}  ${_formatChartValue(selectedPoint.value, chart.unit)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF303238),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || details.scale == 1) {
      return;
    }
    setState(() {
      _horizontalScale = (_scaleGestureStartScale * details.scale).clamp(
        1.0,
        4.0,
      );
    });
  }

  void _zoomBy(double factor) {
    setState(() {
      _horizontalScale = (_horizontalScale * factor).clamp(1.0, 4.0);
    });
  }

  void _selectPoint(Offset localPosition, Size size) {
    final points = widget.chart.points;
    if (points.isEmpty || size.width <= 0) {
      return;
    }
    final ratio = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final targetMillis =
        widget.chart.rangeStart.millisecondsSinceEpoch +
        widget.chart.rangeEnd
                .difference(widget.chart.rangeStart)
                .inMilliseconds *
            ratio;
    var nearest = points.first;
    var nearestDistance =
        (nearest.observedAt.millisecondsSinceEpoch - targetMillis).abs();
    for (final point in points.skip(1)) {
      final distance = (point.observedAt.millisecondsSinceEpoch - targetMillis)
          .abs();
      if (distance < nearestDistance) {
        nearest = point;
        nearestDistance = distance;
      }
    }
    setState(() => _selectedPoint = nearest);
  }
}

class _ChartIconButton extends StatelessWidget {
  const _ChartIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 38,
        height: 38,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFF0B8FD8),
            disabledForegroundColor: const Color(0x668C96A0),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _StatsColumn extends StatelessWidget {
  const _StatsColumn({required this.chart});

  final GoveeH5075HistoryMetricChart chart;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatValue(label: 'Max', value: chart.maximum, unit: chart.unit),
          _StatValue(label: 'Avg', value: chart.average, unit: chart.unit),
          _StatValue(label: 'Min', value: chart.minimum, unit: chart.unit),
        ],
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFF989EA5),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value == null ? '-' : _formatChartValue(value!, unit),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF303238),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryLineChartPainter extends CustomPainter {
  const _HistoryLineChartPainter({
    required this.chart,
    required this.lineColor,
    required this.selectedPoint,
    required this.textStyle,
  });

  final GoveeH5075HistoryMetricChart chart;
  final Color lineColor;
  final GoveeH5075HistoryChartPoint? selectedPoint;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final rect = Rect.fromLTWH(0, 6, size.width, size.height - 28);
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E6EA)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final fraction in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final x = rect.left + rect.width * fraction;
      _drawDashedLine(
        canvas,
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        gridPaint,
      );
    }
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = rect.top + rect.height * fraction;
      _drawDashedLine(
        canvas,
        Offset(rect.left, y),
        Offset(rect.right, y),
        gridPaint,
      );
    }

    final average = chart.average;
    if (average != null) {
      final y = _offsetFor(
        rect,
        GoveeH5075HistoryChartPoint(
          observedAt: chart.rangeStart,
          value: average,
        ),
      ).dy;
      _drawDashedLine(
        canvas,
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()
          ..color = lineColor
          ..strokeWidth = 1.8,
        dash: 5,
        gap: 5,
      );
    }

    final points = chart.points;
    if (points.isEmpty) {
      _drawText(
        canvas,
        'Keine Daten',
        Offset(rect.center.dx - 34, rect.center.dy - 8),
        color: const Color(0xFF989EA5),
      );
      return;
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    var segmentStarted = false;
    for (final point in points) {
      final offset = _offsetFor(rect, point);
      if (!segmentStarted) {
        path.moveTo(offset.dx, offset.dy);
        segmentStarted = true;
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
      if (point.hasGapAfter) {
        segmentStarted = false;
      }
    }
    canvas.drawPath(path, linePaint);

    final selected = selectedPoint;
    if (selected != null) {
      final offset = _offsetFor(rect, selected);
      canvas.drawLine(
        Offset(offset.dx, rect.top),
        Offset(offset.dx, rect.bottom),
        Paint()
          ..color = const Color(0x55303238)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(offset, 5.5, Paint()..color = lineColor);
      canvas.drawCircle(
        offset,
        9,
        Paint()
          ..color = lineColor.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill,
      );
    }

    _drawAxisLabel(canvas, rect.left, rect.bottom + 7, chart.rangeStart);
    _drawAxisLabel(canvas, rect.center.dx - 22, rect.bottom + 7, _middleTime());
    _drawAxisLabel(canvas, rect.right - 44, rect.bottom + 7, chart.rangeEnd);
  }

  DateTime _middleTime() {
    return DateTime.fromMillisecondsSinceEpoch(
      chart.rangeStart.millisecondsSinceEpoch +
          chart.rangeEnd.difference(chart.rangeStart).inMilliseconds ~/ 2,
    );
  }

  Offset _offsetFor(Rect rect, GoveeH5075HistoryChartPoint point) {
    final timeSpan = math.max(
      1,
      chart.rangeEnd.difference(chart.rangeStart).inMilliseconds,
    );
    final valueSpan = math.max(
      0.001,
      chart.displayMaximum - chart.displayMinimum,
    );
    final xRatio =
        (point.observedAt.difference(chart.rangeStart).inMilliseconds /
                timeSpan)
            .clamp(0.0, 1.0);
    final yRatio = ((point.value - chart.displayMinimum) / valueSpan).clamp(
      0.0,
      1.0,
    );
    return Offset(
      rect.left + rect.width * xRatio,
      rect.bottom - rect.height * yRatio,
    );
  }

  void _drawAxisLabel(Canvas canvas, double x, double y, DateTime timestamp) {
    _drawText(
      canvas,
      _formatAxisDate(timestamp),
      Offset(x, y),
      color: const Color(0xFF303238),
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    double dash = 4,
    double gap = 5,
  }) {
    final distance = (to - from).distance;
    if (distance <= 0) {
      return;
    }
    final direction = (to - from) / distance;
    var current = 0.0;
    while (current < distance) {
      final next = math.min(current + dash, distance);
      canvas.drawLine(
        from + direction * current,
        from + direction * next,
        paint,
      );
      current = next + gap;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 70);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _HistoryLineChartPainter oldDelegate) {
    return oldDelegate.chart != chart ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.selectedPoint != selectedPoint ||
        oldDelegate.textStyle != textStyle;
  }
}

String _formatNumber(double value, {int decimals = 1}) {
  return value.toStringAsFixed(decimals).replaceAll('.', ',');
}

String _formatChartValue(double value, String unit) {
  final suffix = unit == 'C' ? '°C' : unit;
  return '${_formatNumber(value)}$suffix';
}

String _formatDateTime(DateTime? timestamp) {
  if (timestamp == null) {
    return '-';
  }
  return '${_twoDigits(timestamp.hour)}:${_twoDigits(timestamp.minute)}, ${timestamp.day}. ${_monthName(timestamp.month)}';
}

String _formatDateTimeShort(DateTime timestamp) {
  return '${_twoDigits(timestamp.hour)}:${_twoDigits(timestamp.minute)}, ${timestamp.day}. ${_monthName(timestamp.month)}';
}

String _formatAxisDate(DateTime timestamp) {
  return '${timestamp.day}. ${_monthName(timestamp.month)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _monthName(int month) {
  return const [
    'Jan.',
    'Feb.',
    'Mrz.',
    'Apr.',
    'Mai',
    'Jun.',
    'Jul.',
    'Aug.',
    'Sep.',
    'Okt.',
    'Nov.',
    'Dez.',
  ][month - 1];
}
