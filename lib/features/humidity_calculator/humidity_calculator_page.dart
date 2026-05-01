import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/psychrometrics/psychrometrics.dart';
import '../weather/example_places.dart';
import '../weather/weather_measurement.dart';
import '../weather/weather_service.dart';

enum _InputMode { manual, place, examples }

class HumidityCalculatorPage extends StatefulWidget {
  HumidityCalculatorPage({super.key, WeatherService? weatherService})
    : weatherService = weatherService ?? OpenMeteoWeatherService();

  final WeatherService weatherService;

  @override
  State<HumidityCalculatorPage> createState() => _HumidityCalculatorPageState();
}

class _HumidityCalculatorPageState extends State<HumidityCalculatorPage> {
  final _temperatureController = TextEditingController(text: '21.0');
  final _humidityController = TextEditingController(text: '50');
  final _pressureController = TextEditingController();
  final _placeController = TextEditingController();

  _InputMode _inputMode = _InputMode.manual;
  WeatherMeasurement? _measurement;
  PsychrometricResult? _result;
  String? _error;
  String? _weatherMessage;
  bool _isLoadingWeather = false;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _humidityController.dispose();
    _pressureController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final measurement = _manualMeasurement();
    if (measurement == null) {
      return;
    }
    _showMeasurement(measurement);
  }

  WeatherMeasurement? _manualMeasurement() {
    final temperature = _parseDecimal(_temperatureController.text);
    final humidity = _parseDecimal(_humidityController.text);
    final pressureText = _pressureController.text.trim();
    final pressure = pressureText.isEmpty ? null : _parseDecimal(pressureText);

    if (temperature == null ||
        humidity == null ||
        pressureText.isNotEmpty && pressure == null) {
      setState(() {
        _result = null;
        _error = 'Bitte Zahlenwerte eingeben.';
      });
      return null;
    }

    final now = DateTime.now();
    return WeatherMeasurement(
      temperatureCelsius: temperature,
      relativeHumidityPercent: humidity,
      pressureHPa: pressure,
      source: MeasurementSource.manual,
      label: 'Manuelle Eingabe',
      observedAt: now,
      fetchedAt: now,
    );
  }

  void _showMeasurement(WeatherMeasurement measurement) {
    try {
      final nextResult = Psychrometrics.calculate(
        measurement.toPsychrometricInput(),
      );
      setState(() {
        _measurement = measurement;
        _result = nextResult;
        _error = null;
      });
    } on ArgumentError catch (error) {
      setState(() {
        _result = null;
        _error =
            error.message?.toString() ?? 'Eingaben ausserhalb des Bereichs.';
      });
    }
  }

  Future<void> _searchPlace() async {
    final query = _placeController.text.trim();
    if (query.length < 2) {
      setState(() {
        _inputMode = _InputMode.place;
        _weatherMessage = 'Bitte mindestens zwei Zeichen eingeben.';
      });
      return;
    }
    await _loadWeather(
      mode: _InputMode.place,
      loader: () async {
        final places = await widget.weatherService.searchPlaces(query);
        if (places.isEmpty) {
          throw const WeatherServiceException(
            'Ort nicht gefunden. Bitte Schreibweise pruefen.',
          );
        }
        return widget.weatherService.fetchWeatherForPlace(
          place: places.first,
          source: MeasurementSource.place,
        );
      },
    );
  }

  void _selectInputMode(_InputMode mode) {
    setState(() => _inputMode = mode);
    if (mode == _InputMode.manual) {
      _recalculate();
    }
  }

  Future<void> _loadExamplePlace(WeatherPlace place) {
    return _loadWeather(
      mode: _InputMode.examples,
      loader: () => widget.weatherService.fetchWeatherForPlace(
        place: place,
        source: MeasurementSource.examplePlace,
      ),
    );
  }

  Future<void> _loadWeather({
    required _InputMode mode,
    required Future<WeatherMeasurement> Function() loader,
  }) async {
    setState(() {
      _inputMode = mode;
      _isLoadingWeather = true;
      _weatherMessage = null;
    });

    try {
      final measurement = await loader();
      if (!mounted) {
        return;
      }
      _showMeasurement(measurement);
      setState(() {
        _inputMode = mode;
        _isLoadingWeather = false;
        _weatherMessage = '${measurement.label} geladen.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final fallback = _manualMeasurement();
      setState(() {
        _inputMode = _InputMode.manual;
        _isLoadingWeather = false;
        _weatherMessage = _messageFor(error);
      });
      if (fallback != null) {
        _showMeasurement(fallback);
      }
    }
  }

  String _messageFor(Object error) {
    if (error is WeatherServiceException) {
      return error.message;
    }
    return 'Wetterdaten konnten nicht geladen werden. Manuelle Eingabe bleibt nutzbar.';
  }

  double? _parseDecimal(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dewprofi'), centerTitle: false),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 840;
            final result = _result;

            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 16,
                vertical: 20,
              ),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 360,
                              child: _InputPanel(
                                temperatureController: _temperatureController,
                                humidityController: _humidityController,
                                pressureController: _pressureController,
                                placeController: _placeController,
                                inputMode: _inputMode,
                                isLoadingWeather: _isLoadingWeather,
                                weatherMessage: _weatherMessage,
                                onChanged: _recalculate,
                                onModeChanged: _selectInputMode,
                                onSearchPlace: _searchPlace,
                                onExamplePlaceSelected: _loadExamplePlace,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _ResultColumn(
                                result: result,
                                measurement: _measurement,
                                error: _error,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _InputPanel(
                              temperatureController: _temperatureController,
                              humidityController: _humidityController,
                              pressureController: _pressureController,
                              placeController: _placeController,
                              inputMode: _inputMode,
                              isLoadingWeather: _isLoadingWeather,
                              weatherMessage: _weatherMessage,
                              onChanged: _recalculate,
                              onModeChanged: _selectInputMode,
                              onSearchPlace: _searchPlace,
                              onExamplePlaceSelected: _loadExamplePlace,
                            ),
                            const SizedBox(height: 16),
                            _ResultColumn(
                              result: result,
                              measurement: _measurement,
                              error: _error,
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InputPanel extends StatelessWidget {
  const _InputPanel({
    required this.temperatureController,
    required this.humidityController,
    required this.pressureController,
    required this.placeController,
    required this.inputMode,
    required this.isLoadingWeather,
    required this.onModeChanged,
    required this.onChanged,
    required this.onSearchPlace,
    required this.onExamplePlaceSelected,
    this.weatherMessage,
  });

  final TextEditingController temperatureController;
  final TextEditingController humidityController;
  final TextEditingController pressureController;
  final TextEditingController placeController;
  final _InputMode inputMode;
  final bool isLoadingWeather;
  final ValueChanged<_InputMode> onModeChanged;
  final VoidCallback onChanged;
  final VoidCallback onSearchPlace;
  final ValueChanged<WeatherPlace> onExamplePlaceSelected;
  final String? weatherMessage;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Datenquelle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<_InputMode>(
            segments: const [
              ButtonSegment(
                value: _InputMode.manual,
                label: Text('Manuell'),
                icon: Icon(Icons.tune),
              ),
              ButtonSegment(
                value: _InputMode.place,
                label: Text('Ort'),
                icon: Icon(Icons.search),
              ),
              ButtonSegment(
                value: _InputMode.examples,
                label: Text('Beispiele'),
                icon: Icon(Icons.location_city),
              ),
            ],
            selected: {inputMode},
            onSelectionChanged: (selection) => onModeChanged(selection.single),
          ),
          const SizedBox(height: 16),
          if (inputMode == _InputMode.place) ...[
            TextField(
              controller: placeController,
              decoration: const InputDecoration(
                labelText: 'Ort suchen',
                suffixText: 'Open-Meteo',
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearchPlace(),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: isLoadingWeather ? null : onSearchPlace,
              icon: isLoadingWeather
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download),
              label: const Text('Wetter laden'),
            ),
            const SizedBox(height: 16),
          ],
          if (inputMode == _InputMode.examples) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final place in examplePlaces)
                  ActionChip(
                    avatar: const Icon(Icons.place, size: 18),
                    label: Text(place.name),
                    onPressed: isLoadingWeather
                        ? null
                        : () => onExamplePlaceSelected(place),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (weatherMessage != null) ...[
            _InlineMessage(message: weatherMessage!),
            const SizedBox(height: 16),
          ],
          Text(
            'Manuelle Werte',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _NumberField(
            controller: temperatureController,
            label: 'Temperatur',
            suffix: '°C',
            signed: true,
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          _NumberField(
            controller: humidityController,
            label: 'Relative Luftfeuchte',
            suffix: '%',
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          _NumberField(
            controller: pressureController,
            label: 'Luftdruck optional',
            suffix: 'hPa',
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
          Text(
            'Default: ${_formatNumber(defaultAtmosphericPressureHPa, decimals: 2)} hPa',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.onChanged,
    this.signed = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final VoidCallback onChanged;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: signed,
      ),
      textInputAction: TextInputAction.next,
      onChanged: (_) => onChanged(),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _ResultColumn extends StatelessWidget {
  const _ResultColumn({
    required this.result,
    required this.measurement,
    required this.error,
  });

  final PsychrometricResult? result;
  final WeatherMeasurement? measurement;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final error = this.error;

    if (error != null) {
      return _Panel(
        child: Text(
          error,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (result == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultPanel(result: result, measurement: measurement),
        const SizedBox(height: 16),
        _HumidityChart(result: result),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result, required this.measurement});

  final PsychrometricResult result;
  final WeatherMeasurement? measurement;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  measurement?.label ?? 'Ergebnis',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _ZonePill(zone: result.zone),
            ],
          ),
          if (measurement != null) ...[
            const SizedBox(height: 6),
            Text(
              _measurementSubtitle(measurement!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MetricTile(
                label: 'Temperatur',
                value: '${_formatNumber(result.temperatureCelsius)} °C',
              ),
              _MetricTile(
                label: 'Relative Feuchte',
                value: '${_formatNumber(result.relativeHumidityPercent)} %',
              ),
              _MetricTile(
                label: 'Taupunkt',
                value: result.dewPointCelsius == null
                    ? 'unter Messbereich'
                    : '${_formatNumber(result.dewPointCelsius!)} °C',
              ),
              _MetricTile(
                label: 'Absolute Feuchte',
                value: '${_formatNumber(result.absoluteHumidityGM3)} g/m³',
              ),
              _MetricTile(
                label: 'Druck',
                value: '${_formatNumber(result.pressureHPa, decimals: 2)} hPa',
              ),
              if (measurement != null)
                _MetricTile(
                  label: 'Datenalter',
                  value: _formatAge(measurement!.ageAt(DateTime.now())),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZonePill extends StatelessWidget {
  const _ZonePill({required this.zone});

  final HumidityZone zone;

  @override
  Widget build(BuildContext context) {
    final color = _zoneColor(zone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          zone.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HumidityChart extends StatelessWidget {
  const _HumidityChart({required this.result});

  final PsychrometricResult result;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Temperatur-Feuchte-Grafik',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: CustomPaint(
              key: const ValueKey('humidity-curve-chart'),
              painter: _HumidityCurvePainter(
                result: result,
                textStyle:
                    Theme.of(context).textTheme.labelSmall ??
                    const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _HumidityCurvePainter extends CustomPainter {
  const _HumidityCurvePainter({required this.result, required this.textStyle});

  final PsychrometricResult result;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final plotRect = Rect.fromLTWH(
      44,
      14,
      math.max(1, size.width - 64),
      math.max(1, size.height - 50),
    );
    final dewPoint = result.dewPointCelsius;
    final minTemperature = math
        .min(
          result.temperatureCelsius - 8,
          (dewPoint ?? result.temperatureCelsius) - 4,
        )
        .floorToDouble();
    final maxTemperature = math
        .max(result.temperatureCelsius + 14, result.temperatureCelsius + 4)
        .ceilToDouble();

    double xForTemperature(double temperature) {
      return plotRect.left +
          (temperature - minTemperature) /
              (maxTemperature - minTemperature) *
              plotRect.width;
    }

    double yForHumidity(double humidity) {
      return plotRect.bottom - (humidity.clamp(0, 100) / 100) * plotRect.height;
    }

    void drawBand(double minHumidity, double maxHumidity, Color color) {
      final top = yForHumidity(maxHumidity);
      final bottom = yForHumidity(minHumidity);
      canvas.drawRect(
        Rect.fromLTRB(plotRect.left, top, plotRect.right, bottom),
        Paint()..color = color,
      );
    }

    drawBand(0, 40, const Color(0xFFE0F2FE));
    drawBand(40, 60, const Color(0xFFD9F99D));
    drawBand(60, 70, const Color(0xFFFEF3C7));
    drawBand(70, 100, const Color(0xFFFEE2E2));

    final gridPaint = Paint()
      ..color = const Color(0xFFAAA59A)
      ..strokeWidth = 1;
    for (final humidity in [0, 40, 60, 70, 100]) {
      final y = yForHumidity(humidity.toDouble());
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        gridPaint,
      );
      _drawText(
        canvas,
        '${humidity.toInt()}%',
        Offset(4, y - 7),
        color: const Color(0xFF56524A),
      );
    }

    for (final temperature in _temperatureTicks(
      minTemperature,
      maxTemperature,
    )) {
      final x = xForTemperature(temperature);
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        gridPaint..color = const Color(0x55AAA59A),
      );
      _drawText(
        canvas,
        '${temperature.toInt()}°',
        Offset(x - 12, plotRect.bottom + 10),
        color: const Color(0xFF56524A),
      );
    }

    canvas.drawRect(
      plotRect,
      Paint()
        ..color = const Color(0xFF403C34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final path = Path();
    const samples = 120;
    for (var i = 0; i <= samples; i++) {
      final temperature =
          minTemperature + (maxTemperature - minTemperature) * i / samples;
      final relativeHumidity =
          Psychrometrics.relativeHumidityForAbsoluteHumidity(
            temperatureCelsius: temperature,
            absoluteHumidityGM3: result.absoluteHumidityGM3,
          );
      final point = Offset(
        xForTemperature(temperature),
        yForHumidity(relativeHumidity),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final curvePaint = Paint()
      ..color = const Color(0xFF0F766E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, curvePaint);

    if (dewPoint != null) {
      final x = xForTemperature(dewPoint);
      final dewPaint = Paint()
        ..color = const Color(0xFFB45309)
        ..strokeWidth = 1.5;
      _drawDashedLine(
        canvas,
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        dewPaint,
      );
      _drawText(
        canvas,
        'Taupunkt',
        Offset(
          (x + 5).clamp(plotRect.left, plotRect.right - 55),
          plotRect.top + 6,
        ),
        color: const Color(0xFF92400E),
      );
    }

    final currentPoint = Offset(
      xForTemperature(result.temperatureCelsius),
      yForHumidity(result.relativeHumidityPercent),
    );
    canvas.drawCircle(
      currentPoint,
      7,
      Paint()..color = const Color(0xFF4F46E5),
    );
    canvas.drawCircle(
      currentPoint,
      10,
      Paint()
        ..color = const Color(0xFF4F46E5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawText(
      canvas,
      'Aktuell',
      Offset(
        (currentPoint.dx + 8).clamp(plotRect.left, plotRect.right - 48),
        (currentPoint.dy - 22).clamp(plotRect.top, plotRect.bottom - 16),
      ),
      color: const Color(0xFF3730A3),
    );
  }

  Iterable<double> _temperatureTicks(
    double minTemperature,
    double maxTemperature,
  ) sync* {
    final first = (minTemperature / 5).ceil() * 5;
    for (var value = first; value <= maxTemperature; value += 5) {
      yield value.toDouble();
    }
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 6.0;
    const gap = 5.0;
    final distance = (to - from).distance;
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
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _HumidityCurvePainter oldDelegate) {
    return oldDelegate.result != result || oldDelegate.textStyle != textStyle;
  }
}

Color _zoneColor(HumidityZone zone) {
  return switch (zone) {
    HumidityZone.dry => const Color(0xFF0369A1),
    HumidityZone.comfortable => const Color(0xFF166534),
    HumidityZone.humid => const Color(0xFFB45309),
    HumidityZone.critical => const Color(0xFFB91C1C),
  };
}

String _formatNumber(double value, {int decimals = 1}) {
  return value.toStringAsFixed(decimals).replaceAll('.', ',');
}

String _measurementSubtitle(WeatherMeasurement measurement) {
  return '${measurement.source.label} · aktualisiert ${_formatClock(measurement.fetchedAt)}';
}

String _formatClock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatAge(Duration age) {
  final normalized = age.isNegative ? Duration.zero : age;
  if (normalized.inMinutes < 1) {
    return 'gerade eben';
  }
  if (normalized.inHours < 1) {
    return '${normalized.inMinutes} min';
  }
  return '${normalized.inHours} h';
}
