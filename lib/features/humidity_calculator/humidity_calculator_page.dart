import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/storage/calculator_preferences_store.dart';
import '../../core/psychrometrics/psychrometrics.dart';
import '../location/location_service.dart';
import '../weather/example_places.dart';
import '../weather/weather_measurement.dart';
import '../weather/weather_service.dart';

enum _InputMode { manual, location, place, examples }

enum _DetailMode { simple, pro }

class HumidityCalculatorPage extends StatefulWidget {
  HumidityCalculatorPage({
    super.key,
    WeatherService? weatherService,
    CalculatorPreferencesStore? preferencesStore,
    LocationService? locationService,
  }) : weatherService = weatherService ?? OpenMeteoWeatherService(),
       preferencesStore =
           preferencesStore ??
           const SharedPreferencesCalculatorPreferencesStore(),
       locationService = locationService ?? GeolocatorLocationService();

  final WeatherService weatherService;
  final CalculatorPreferencesStore preferencesStore;
  final LocationService locationService;

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
  bool _isInputExpanded = false;
  bool _hasLoadedPreferences = false;
  _DetailMode _detailMode = _DetailMode.simple;
  WeatherPlace? _selectedPlace;

  @override
  void initState() {
    super.initState();
    _recalculate(persist: false);
    _restorePreferences();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _humidityController.dispose();
    _pressureController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _restorePreferences() async {
    final preferences = await widget.preferencesStore.load();
    if (!mounted) {
      return;
    }

    if (preferences == null) {
      setState(() => _hasLoadedPreferences = true);
      return;
    }

    var inputMode = _inputModeFromPreference(preferences.inputMode);
    if (inputMode != _InputMode.manual && preferences.measurement == null) {
      inputMode = _InputMode.manual;
    }
    final detailMode = _detailModeFromPreference(preferences.detailMode);
    _temperatureController.text = preferences.manualTemperatureText;
    _humidityController.text = preferences.manualHumidityText;
    _pressureController.text = preferences.manualPressureText;
    _placeController.text =
        preferences.placeQuery ?? preferences.selectedPlace?.displayName ?? '';
    _selectedPlace = preferences.selectedPlace;

    setState(() {
      _inputMode = inputMode;
      _detailMode = detailMode;
      _isInputExpanded = preferences.isInputExpanded;
      _hasLoadedPreferences = true;
      _weatherMessage = _restoredMessageFor(inputMode, preferences.measurement);
    });

    final measurement = preferences.measurement;
    if (inputMode != _InputMode.manual && measurement != null) {
      _showMeasurement(measurement, persist: false);
    } else {
      _recalculate(persist: false);
    }
  }

  void _recalculate({bool persist = true}) {
    final measurement = _manualMeasurement();
    if (measurement == null) {
      return;
    }
    _showMeasurement(measurement, persist: persist);
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

  void _showMeasurement(WeatherMeasurement measurement, {bool persist = true}) {
    try {
      final nextResult = Psychrometrics.calculate(
        measurement.toPsychrometricInput(),
      );
      setState(() {
        _measurement = measurement;
        _result = nextResult;
        _error = null;
      });
      if (persist) {
        _persistPreferences(measurement: measurement);
      }
    } on ArgumentError catch (error) {
      setState(() {
        _result = null;
        _error =
            error.message?.toString() ?? 'Eingaben ausserhalb des Bereichs.';
      });
    }
  }

  void _applyChartMeasurement({
    required double temperatureCelsius,
    required double relativeHumidityPercent,
  }) {
    final now = DateTime.now();
    final pressureText = _pressureController.text.trim();
    final pressure = pressureText.isEmpty ? null : _parseDecimal(pressureText);
    final measurement = WeatherMeasurement(
      temperatureCelsius: temperatureCelsius,
      relativeHumidityPercent: relativeHumidityPercent,
      pressureHPa: pressure,
      source: MeasurementSource.manual,
      label: 'Manuelle Eingabe',
      observedAt: now,
      fetchedAt: now,
    );

    _temperatureController.text = _formatNumber(temperatureCelsius);
    _humidityController.text = relativeHumidityPercent.toStringAsFixed(0);
    setState(() {
      _inputMode = _InputMode.manual;
      _weatherMessage = 'Diagrammwert uebernommen.';
      _selectedPlace = null;
    });
    _showMeasurement(measurement);
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
    WeatherPlace? selectedPlace;
    await _loadWeather(
      mode: _InputMode.place,
      selectedPlaceProvider: () => selectedPlace,
      loader: () async {
        final places = await widget.weatherService.searchPlaces(query);
        if (places.isEmpty) {
          throw const WeatherServiceException(
            'Ort nicht gefunden. Bitte Schreibweise pruefen.',
          );
        }
        selectedPlace = places.first;
        return widget.weatherService.fetchWeatherForPlace(
          place: selectedPlace!,
          source: MeasurementSource.place,
        );
      },
    );
  }

  void _selectInputMode(_InputMode mode) {
    setState(() => _inputMode = mode);
    _persistPreferences(measurement: _measurement);
    if (mode == _InputMode.manual) {
      _recalculate();
    }
  }

  Future<void> _loadExamplePlace(WeatherPlace place) {
    return _loadWeather(
      mode: _InputMode.examples,
      selectedPlaceProvider: () => place,
      loader: () => widget.weatherService.fetchWeatherForPlace(
        place: place,
        source: MeasurementSource.examplePlace,
      ),
    );
  }

  Future<void> _loadCurrentLocation() {
    return _loadWeather(
      mode: _InputMode.location,
      fallbackMode: _InputMode.place,
      applyManualFallback: false,
      loader: () async {
        final coordinates = await widget.locationService.currentCoordinates();
        return widget.weatherService.fetchWeather(
          coordinates: coordinates,
          source: MeasurementSource.location,
          label: 'Aktueller Standort',
        );
      },
    );
  }

  Future<void> _loadWeather({
    required _InputMode mode,
    required Future<WeatherMeasurement> Function() loader,
    WeatherPlace? Function()? selectedPlaceProvider,
    _InputMode fallbackMode = _InputMode.manual,
    bool applyManualFallback = true,
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
      _selectedPlace = selectedPlaceProvider?.call();
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
      final fallback = applyManualFallback ? _manualMeasurement() : null;
      setState(() {
        _inputMode = fallbackMode;
        _isLoadingWeather = false;
        _weatherMessage = _messageFor(error);
        _selectedPlace = null;
      });
      if (fallback != null) {
        _showMeasurement(fallback);
      }
    }
  }

  Future<void> _refreshStoredWeather() async {
    final place = _selectedPlace;
    final measurement = _measurement;
    if (place == null || measurement == null) {
      return;
    }
    await _loadWeather(
      mode: _inputMode,
      selectedPlaceProvider: () => place,
      loader: () => widget.weatherService.fetchWeatherForPlace(
        place: place,
        source: measurement.source,
      ),
    );
  }

  Future<void> _persistPreferences({WeatherMeasurement? measurement}) async {
    if (!_hasLoadedPreferences) {
      return;
    }

    await widget.preferencesStore.save(
      CalculatorPreferences(
        inputMode: _inputMode.name,
        detailMode: _detailMode.name,
        manualTemperatureText: _temperatureController.text,
        manualHumidityText: _humidityController.text,
        manualPressureText: _pressureController.text,
        isInputExpanded: _isInputExpanded,
        placeQuery: _placeController.text.trim().isEmpty
            ? null
            : _placeController.text.trim(),
        selectedPlace: _selectedPlace,
        measurement: measurement ?? _measurement,
      ),
    );
  }

  bool get _canRefreshStoredWeather =>
      _selectedPlace != null &&
      _measurement != null &&
      (_inputMode == _InputMode.place || _inputMode == _InputMode.examples) &&
      !_isLoadingWeather;

  void _toggleInputExpanded() {
    setState(() => _isInputExpanded = !_isInputExpanded);
    _persistPreferences();
  }

  void _changeDetailMode(_DetailMode mode) {
    setState(() => _detailMode = mode);
    _persistPreferences();
  }

  _InputMode _inputModeFromPreference(String value) {
    for (final mode in _InputMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return _InputMode.manual;
  }

  _DetailMode _detailModeFromPreference(String value) {
    for (final mode in _DetailMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return _DetailMode.simple;
  }

  String? _restoredMessageFor(
    _InputMode inputMode,
    WeatherMeasurement? measurement,
  ) {
    if (inputMode == _InputMode.manual || measurement == null) {
      return null;
    }
    return 'Gespeicherte Wetterwerte vom letzten Abruf.';
  }

  String _messageFor(Object error) {
    if (error is WeatherServiceException) {
      return error.message;
    }
    if (error is LocationServiceException) {
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
                                result: result,
                                measurement: _measurement,
                                temperatureController: _temperatureController,
                                humidityController: _humidityController,
                                pressureController: _pressureController,
                                placeController: _placeController,
                                inputMode: _inputMode,
                                isExpanded: _isInputExpanded,
                                isLoadingWeather: _isLoadingWeather,
                                weatherMessage: _weatherMessage,
                                canRefreshWeather: _canRefreshStoredWeather,
                                onRefreshWeather: _refreshStoredWeather,
                                onToggleExpanded: _toggleInputExpanded,
                                onChanged: _recalculate,
                                onModeChanged: _selectInputMode,
                                onUseLocation: _loadCurrentLocation,
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
                                detailMode: _detailMode,
                                onDetailModeChanged: _changeDetailMode,
                                onChartMeasurementChanged:
                                    _applyChartMeasurement,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _InputPanel(
                              result: result,
                              measurement: _measurement,
                              temperatureController: _temperatureController,
                              humidityController: _humidityController,
                              pressureController: _pressureController,
                              placeController: _placeController,
                              inputMode: _inputMode,
                              isExpanded: _isInputExpanded,
                              isLoadingWeather: _isLoadingWeather,
                              weatherMessage: _weatherMessage,
                              canRefreshWeather: _canRefreshStoredWeather,
                              onRefreshWeather: _refreshStoredWeather,
                              onToggleExpanded: _toggleInputExpanded,
                              onChanged: _recalculate,
                              onModeChanged: _selectInputMode,
                              onUseLocation: _loadCurrentLocation,
                              onSearchPlace: _searchPlace,
                              onExamplePlaceSelected: _loadExamplePlace,
                            ),
                            const SizedBox(height: 16),
                            _ResultColumn(
                              result: result,
                              measurement: _measurement,
                              error: _error,
                              detailMode: _detailMode,
                              onDetailModeChanged: _changeDetailMode,
                              onChartMeasurementChanged: _applyChartMeasurement,
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
    required this.result,
    required this.measurement,
    required this.temperatureController,
    required this.humidityController,
    required this.pressureController,
    required this.placeController,
    required this.inputMode,
    required this.isExpanded,
    required this.isLoadingWeather,
    required this.canRefreshWeather,
    required this.onToggleExpanded,
    required this.onModeChanged,
    required this.onUseLocation,
    required this.onChanged,
    required this.onSearchPlace,
    required this.onRefreshWeather,
    required this.onExamplePlaceSelected,
    this.weatherMessage,
  });

  final PsychrometricResult? result;
  final WeatherMeasurement? measurement;
  final TextEditingController temperatureController;
  final TextEditingController humidityController;
  final TextEditingController pressureController;
  final TextEditingController placeController;
  final _InputMode inputMode;
  final bool isExpanded;
  final bool isLoadingWeather;
  final bool canRefreshWeather;
  final VoidCallback onToggleExpanded;
  final ValueChanged<_InputMode> onModeChanged;
  final VoidCallback onUseLocation;
  final VoidCallback onChanged;
  final VoidCallback onSearchPlace;
  final VoidCallback onRefreshWeather;
  final ValueChanged<WeatherPlace> onExamplePlaceSelected;
  final String? weatherMessage;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompactInputRow(
            result: result,
            measurement: measurement,
            isExpanded: isExpanded,
            onTap: onToggleExpanded,
          ),
          if (isExpanded) ...[
            const SizedBox(height: 16),
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
                  value: _InputMode.location,
                  label: Text('Standort'),
                  icon: Icon(Icons.my_location),
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
              onSelectionChanged: (selection) =>
                  onModeChanged(selection.single),
            ),
            const SizedBox(height: 16),
            if (inputMode == _InputMode.location) ...[
              Text(
                'Standort nutzt einmalig deine aktuelle Position, um Wetterwerte fuer deine Umgebung zu laden.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: isLoadingWeather ? null : onUseLocation,
                icon: isLoadingWeather
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Standort verwenden'),
              ),
              const SizedBox(height: 16),
            ],
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
              if (canRefreshWeather) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onRefreshWeather,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Aktualisieren'),
                ),
              ],
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
        ],
      ),
    );
  }
}

class _CompactInputRow extends StatelessWidget {
  const _CompactInputRow({
    required this.result,
    required this.measurement,
    required this.isExpanded,
    required this.onTap,
  });

  final PsychrometricResult? result;
  final WeatherMeasurement? measurement;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final theme = Theme.of(context);
    final subtitle = measurement == null
        ? 'manuell'
        : '${measurement!.source.label} · ${measurement!.label}';

    return InkWell(
      key: const ValueKey('compact-input-row'),
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          children: [
            Icon(
              Icons.tune,
              color: theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result == null
                        ? 'Werte eingeben'
                        : '${_formatNumber(result.temperatureCelsius)} °C · ${_formatNumber(result.relativeHumidityPercent, decimals: 0)} %',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
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
    required this.detailMode,
    required this.onDetailModeChanged,
    required this.onChartMeasurementChanged,
  });

  final PsychrometricResult? result;
  final WeatherMeasurement? measurement;
  final String? error;
  final _DetailMode detailMode;
  final ValueChanged<_DetailMode> onDetailModeChanged;
  final void Function({
    required double temperatureCelsius,
    required double relativeHumidityPercent,
  })
  onChartMeasurementChanged;

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
        _HumidityChart(
          result: result,
          onMeasurementChanged: onChartMeasurementChanged,
        ),
        const SizedBox(height: 16),
        _ResultPanel(
          result: result,
          measurement: measurement,
          detailMode: detailMode,
          onDetailModeChanged: onDetailModeChanged,
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.measurement,
    required this.detailMode,
    required this.onDetailModeChanged,
  });

  final PsychrometricResult result;
  final WeatherMeasurement? measurement;
  final _DetailMode detailMode;
  final ValueChanged<_DetailMode> onDetailModeChanged;

  @override
  Widget build(BuildContext context) {
    final isPro = detailMode == _DetailMode.pro;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 210,
                child: Text(
                  measurement?.label ?? 'Ergebnis',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _ZonePill(zone: result.zone),
              SegmentedButton<_DetailMode>(
                key: const ValueKey('detail-mode-segmented-button'),
                segments: const [
                  ButtonSegment(
                    value: _DetailMode.simple,
                    label: Text('Einfach'),
                    icon: Icon(Icons.visibility),
                  ),
                  ButtonSegment(
                    value: _DetailMode.pro,
                    label: Text('Profi'),
                    icon: Icon(Icons.analytics),
                  ),
                ],
                selected: {detailMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    onDetailModeChanged(selection.single),
              ),
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
            ],
          ),
          if (isPro) ...[
            const SizedBox(height: 18),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _MetricTile(
                  label: 'Absolute Feuchte',
                  value: '${_formatNumber(result.absoluteHumidityGM3)} g/m³',
                ),
                _MetricTile(
                  label: 'Druck',
                  value:
                      '${_formatNumber(result.pressureHPa, decimals: 2)} hPa',
                ),
                _MetricTile(
                  label: 'Saettigungsdampfdruck',
                  value:
                      '${_formatNumber(result.saturationVaporPressureHPa, decimals: 2)} hPa',
                ),
                _MetricTile(
                  label: 'Dampfdruck',
                  value:
                      '${_formatNumber(result.vaporPressureHPa, decimals: 2)} hPa',
                ),
                _MetricTile(
                  label: 'Taupunktabstand',
                  value: result.dewPointSpreadCelsius.isFinite
                      ? '${_formatNumber(result.dewPointSpreadCelsius)} °C'
                      : 'nicht bestimmbar',
                ),
                if (measurement != null) ...[
                  _MetricTile(
                    label: 'Quelle',
                    value: _sourceLabel(measurement!),
                  ),
                  _MetricTile(
                    label: 'Datenalter',
                    value: _formatAge(measurement!.ageAt(DateTime.now())),
                  ),
                ],
              ],
            ),
          ],
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

class _HumidityChart extends StatefulWidget {
  const _HumidityChart({
    required this.result,
    required this.onMeasurementChanged,
  });

  final PsychrometricResult result;
  final void Function({
    required double temperatureCelsius,
    required double relativeHumidityPercent,
  })
  onMeasurementChanged;

  @override
  State<_HumidityChart> createState() => _HumidityChartState();
}

class _HumidityChartState extends State<_HumidityChart> {
  _ChartViewport? _manualViewport;
  _ChartViewport? _gestureStartViewport;
  Offset? _gestureStartFocalPoint;
  _ChartDragMode _dragMode = _ChartDragMode.none;
  _ChartPoint? _dragPreview;
  int? _activePointer;
  int _pointerCount = 0;
  bool _curveLockEnabled = false;

  bool get _isAutoFit => _manualViewport == null;

  @override
  void didUpdateWidget(covariant _HumidityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _dragPreview = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle =
        Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 11);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Temperatur-Feuchte-Grafik',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Tooltip(
                message: _curveLockEnabled
                    ? 'Kurvensperre aktiv'
                    : 'Kurvensperre aus',
                child: IconButton.filledTonal(
                  key: const ValueKey('chart-curve-lock-button'),
                  isSelected: _curveLockEnabled,
                  onPressed: () =>
                      setState(() => _curveLockEnabled = !_curveLockEnabled),
                  icon: Icon(_curveLockEnabled ? Icons.lock : Icons.lock_open),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Ansicht zuruecksetzen',
                child: IconButton.outlined(
                  key: const ValueKey('chart-reset-view-button'),
                  onPressed: _isAutoFit
                      ? null
                      : () => setState(() => _manualViewport = null),
                  icon: const Icon(Icons.restart_alt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final viewport = _effectiveViewport();
                final geometry = _ChartGeometry(size: size, viewport: viewport);

                return Listener(
                  onPointerDown: (event) => _handlePointerDown(event, geometry),
                  onPointerMove: (event) => _handlePointerMove(event, geometry),
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      _zoomAt(
                        localPosition: event.localPosition,
                        scaleFactor: event.scrollDelta.dy > 0 ? 0.88 : 1.12,
                        geometry: geometry,
                      );
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (details) =>
                        _handleScaleStart(details, geometry),
                    onScaleUpdate: (details) =>
                        _handleScaleUpdate(details, geometry),
                    onScaleEnd: (_) => _handleScaleEnd(),
                    child: CustomPaint(
                      key: const ValueKey('humidity-curve-chart'),
                      painter: _HumidityCurvePainter(
                        result: widget.result,
                        viewport: viewport,
                        dragPreview: _dragPreview,
                        isCurveLocked: _curveLockEnabled,
                        textStyle: textStyle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  _ChartViewport _effectiveViewport() {
    return _manualViewport ?? _autoViewportFor(widget.result);
  }

  void _handleScaleStart(ScaleStartDetails details, _ChartGeometry geometry) {
    if (_pointerCount < 2) {
      return;
    }
    final viewport = _effectiveViewport();
    _gestureStartViewport = viewport;
    _gestureStartFocalPoint = details.localFocalPoint;
    _dragMode = _ChartDragMode.pan;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, _ChartGeometry geometry) {
    if (_pointerCount < 2) {
      return;
    }
    final startViewport = _gestureStartViewport;
    final startFocalPoint = _gestureStartFocalPoint;
    if (startViewport == null || startFocalPoint == null) {
      return;
    }

    var nextViewport = startViewport;
    if ((details.scale - 1).abs() > 0.01) {
      final focalPoint = geometry.pointFor(details.localFocalPoint);
      nextViewport = startViewport.zoomedAt(
        focalPoint,
        details.scale.clamp(0.35, 3.5).toDouble(),
      );
    }
    final startGeometry = _ChartGeometry(
      size: geometry.size,
      viewport: nextViewport,
    );
    final startPoint = startGeometry.pointFor(startFocalPoint);
    final currentPoint = startGeometry.pointFor(details.localFocalPoint);
    final deltaTemperature =
        startPoint.temperatureCelsius - currentPoint.temperatureCelsius;
    final deltaHumidity =
        startPoint.relativeHumidityPercent -
        currentPoint.relativeHumidityPercent;

    setState(() {
      _manualViewport = nextViewport
          .translated(
            deltaTemperature: deltaTemperature,
            deltaHumidity: deltaHumidity,
          )
          .normalized();
    });
  }

  void _handleScaleEnd() {
    if (_pointerCount > 0) {
      return;
    }
    _resetGestureState();
  }

  void _handlePointerDown(PointerDownEvent event, _ChartGeometry geometry) {
    _pointerCount += 1;
    if (_pointerCount > 1) {
      _activePointer = null;
      _dragPreview = null;
      return;
    }

    _activePointer = event.pointer;
    _gestureStartViewport = _effectiveViewport();
    _gestureStartFocalPoint = event.localPosition;
    final currentPoint = geometry.offsetFor(
      _ChartPoint(
        temperatureCelsius: widget.result.temperatureCelsius,
        relativeHumidityPercent: widget.result.relativeHumidityPercent,
      ),
    );
    _dragMode = (event.localPosition - currentPoint).distance <= 34
        ? _ChartDragMode.point
        : _ChartDragMode.pan;
    if (_dragMode == _ChartDragMode.point) {
      setState(() {
        _dragPreview = _pointForLocalPosition(event.localPosition, geometry);
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event, _ChartGeometry geometry) {
    if (_activePointer != event.pointer || _pointerCount != 1) {
      return;
    }

    if (_dragMode == _ChartDragMode.point) {
      setState(() {
        _dragPreview = _pointForLocalPosition(event.localPosition, geometry);
      });
      return;
    }

    final startViewport = _gestureStartViewport;
    final startFocalPoint = _gestureStartFocalPoint;
    if (startViewport == null || startFocalPoint == null) {
      return;
    }
    final startGeometry = _ChartGeometry(
      size: geometry.size,
      viewport: startViewport,
    );
    final startPoint = startGeometry.pointFor(startFocalPoint);
    final currentPoint = startGeometry.pointFor(event.localPosition);
    setState(() {
      _manualViewport = startViewport
          .translated(
            deltaTemperature:
                startPoint.temperatureCelsius - currentPoint.temperatureCelsius,
            deltaHumidity:
                startPoint.relativeHumidityPercent -
                currentPoint.relativeHumidityPercent,
          )
          .normalized();
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    _finishPointer(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _finishPointer(event.pointer, applyPreview: false);
  }

  void _finishPointer(int pointer, {bool applyPreview = true}) {
    _pointerCount = math.max(0, _pointerCount - 1);
    if (_activePointer != pointer) {
      if (_pointerCount == 0) {
        _resetGestureState();
      }
      return;
    }
    if (applyPreview) {
      _applyDragPreview();
    }
    _resetGestureState();
  }

  void _applyDragPreview() {
    final preview = _dragPreview;
    if (_dragMode == _ChartDragMode.point && preview != null) {
      widget.onMeasurementChanged(
        temperatureCelsius: preview.temperatureCelsius,
        relativeHumidityPercent: preview.relativeHumidityPercent,
      );
    }
  }

  void _resetGestureState() {
    setState(() {
      _dragMode = _ChartDragMode.none;
      _dragPreview = null;
      _gestureStartViewport = null;
      _gestureStartFocalPoint = null;
      _activePointer = null;
    });
  }

  void _zoomAt({
    required Offset localPosition,
    required double scaleFactor,
    required _ChartGeometry geometry,
  }) {
    final viewport = _effectiveViewport();
    final focalPoint = geometry.pointFor(localPosition);
    setState(() {
      _manualViewport = viewport.zoomedAt(focalPoint, scaleFactor).normalized();
    });
  }

  _ChartPoint _pointForLocalPosition(
    Offset localPosition,
    _ChartGeometry geometry,
  ) {
    final point = geometry.pointFor(localPosition);
    final roundedTemperature = _roundToTenth(
      point.temperatureCelsius.clamp(-80, 80).toDouble(),
    );
    if (_curveLockEnabled) {
      final dewPoint = widget.result.dewPointCelsius;
      final minTemperature = dewPoint == null
          ? -80.0
          : _roundToTenth(math.max(dewPoint, -80));
      final lockedTemperature = _roundToTenth(
        roundedTemperature.clamp(minTemperature, 80).toDouble(),
      );
      final lockedHumidity = Psychrometrics.relativeHumidityForAbsoluteHumidity(
        temperatureCelsius: lockedTemperature,
        absoluteHumidityGM3: widget.result.absoluteHumidityGM3,
      ).clamp(0, 100).toDouble();
      return _ChartPoint(
        temperatureCelsius: lockedTemperature,
        relativeHumidityPercent: _roundToWhole(lockedHumidity),
      );
    }

    return _ChartPoint(
      temperatureCelsius: roundedTemperature,
      relativeHumidityPercent: _roundToWhole(
        point.relativeHumidityPercent.clamp(0, 100).toDouble(),
      ),
    );
  }
}

enum _ChartDragMode { none, pan, point }

class _ChartPoint {
  const _ChartPoint({
    required this.temperatureCelsius,
    required this.relativeHumidityPercent,
  });

  final double temperatureCelsius;
  final double relativeHumidityPercent;
}

class _ChartViewport {
  const _ChartViewport({
    required this.minTemperature,
    required this.maxTemperature,
    required this.minHumidity,
    required this.maxHumidity,
  });

  final double minTemperature;
  final double maxTemperature;
  final double minHumidity;
  final double maxHumidity;

  _ChartViewport translated({
    required double deltaTemperature,
    required double deltaHumidity,
  }) {
    return _ChartViewport(
      minTemperature: minTemperature + deltaTemperature,
      maxTemperature: maxTemperature + deltaTemperature,
      minHumidity: minHumidity + deltaHumidity,
      maxHumidity: maxHumidity + deltaHumidity,
    );
  }

  _ChartViewport zoomedAt(_ChartPoint focalPoint, double scaleFactor) {
    final temperatureSpan = (maxTemperature - minTemperature) / scaleFactor;
    final humiditySpan = (maxHumidity - minHumidity) / scaleFactor;
    final xRatio =
        (focalPoint.temperatureCelsius - minTemperature) /
        (maxTemperature - minTemperature);
    final yRatio =
        (focalPoint.relativeHumidityPercent - minHumidity) /
        (maxHumidity - minHumidity);

    return _ChartViewport(
      minTemperature: focalPoint.temperatureCelsius - temperatureSpan * xRatio,
      maxTemperature:
          focalPoint.temperatureCelsius + temperatureSpan * (1 - xRatio),
      minHumidity: focalPoint.relativeHumidityPercent - humiditySpan * yRatio,
      maxHumidity:
          focalPoint.relativeHumidityPercent + humiditySpan * (1 - yRatio),
    );
  }

  _ChartViewport normalized() {
    const minTemperatureSpan = 4.0;
    const maxTemperatureSpan = 80.0;
    const minHumiditySpan = 20.0;
    final temperatureSpan = (maxTemperature - minTemperature).clamp(
      minTemperatureSpan,
      maxTemperatureSpan,
    );
    final humiditySpan = (maxHumidity - minHumidity).clamp(
      minHumiditySpan,
      100.0,
    );
    final temperatureCenter = (minTemperature + maxTemperature) / 2;
    final humidityCenter = (minHumidity + maxHumidity) / 2;
    final nextMinTemperature = (temperatureCenter - temperatureSpan / 2).clamp(
      -80.0,
      80.0 - temperatureSpan,
    );
    final nextMinHumidity = (humidityCenter - humiditySpan / 2).clamp(
      0.0,
      100.0 - humiditySpan,
    );

    return _ChartViewport(
      minTemperature: nextMinTemperature.toDouble(),
      maxTemperature:
          nextMinTemperature.toDouble() + temperatureSpan.toDouble(),
      minHumidity: nextMinHumidity.toDouble(),
      maxHumidity: nextMinHumidity.toDouble() + humiditySpan.toDouble(),
    );
  }
}

class _ChartGeometry {
  const _ChartGeometry({required this.size, required this.viewport});

  final Size size;
  final _ChartViewport viewport;

  Rect get plotRect {
    return Rect.fromLTWH(
      44,
      14,
      math.max(1, size.width - 64),
      math.max(1, size.height - 50),
    );
  }

  Offset offsetFor(_ChartPoint point) {
    final rect = plotRect;
    return Offset(
      rect.left +
          (point.temperatureCelsius - viewport.minTemperature) /
              (viewport.maxTemperature - viewport.minTemperature) *
              rect.width,
      rect.bottom -
          (point.relativeHumidityPercent - viewport.minHumidity) /
              (viewport.maxHumidity - viewport.minHumidity) *
              rect.height,
    );
  }

  _ChartPoint pointFor(Offset offset) {
    final rect = plotRect;
    final xRatio = ((offset.dx - rect.left) / rect.width).clamp(0.0, 1.0);
    final yRatio = ((rect.bottom - offset.dy) / rect.height).clamp(0.0, 1.0);
    return _ChartPoint(
      temperatureCelsius:
          viewport.minTemperature +
          xRatio * (viewport.maxTemperature - viewport.minTemperature),
      relativeHumidityPercent:
          viewport.minHumidity +
          yRatio * (viewport.maxHumidity - viewport.minHumidity),
    );
  }
}

_ChartViewport _autoViewportFor(PsychrometricResult result) {
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

  return _ChartViewport(
    minTemperature: minTemperature,
    maxTemperature: maxTemperature,
    minHumidity: 0,
    maxHumidity: 100,
  ).normalized();
}

double _roundToTenth(double value) => (value * 10).roundToDouble() / 10;

double _roundToWhole(double value) => value.roundToDouble();

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
  const _HumidityCurvePainter({
    required this.result,
    required this.viewport,
    required this.dragPreview,
    required this.isCurveLocked,
    required this.textStyle,
  });

  final PsychrometricResult result;
  final _ChartViewport viewport;
  final _ChartPoint? dragPreview;
  final bool isCurveLocked;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final geometry = _ChartGeometry(size: size, viewport: viewport);
    final plotRect = geometry.plotRect;
    final dewPoint = result.dewPointCelsius;

    void drawBand(double minHumidity, double maxHumidity, Color color) {
      final top = geometry
          .offsetFor(
            _ChartPoint(
              temperatureCelsius: viewport.minTemperature,
              relativeHumidityPercent: maxHumidity,
            ),
          )
          .dy;
      final bottom = geometry
          .offsetFor(
            _ChartPoint(
              temperatureCelsius: viewport.minTemperature,
              relativeHumidityPercent: minHumidity,
            ),
          )
          .dy;
      canvas.drawRect(
        Rect.fromLTRB(
          plotRect.left,
          top.clamp(plotRect.top, plotRect.bottom).toDouble(),
          plotRect.right,
          bottom.clamp(plotRect.top, plotRect.bottom).toDouble(),
        ),
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
      final y = geometry
          .offsetFor(
            _ChartPoint(
              temperatureCelsius: viewport.minTemperature,
              relativeHumidityPercent: humidity.toDouble(),
            ),
          )
          .dy;
      if (y < plotRect.top - 1 || y > plotRect.bottom + 1) {
        continue;
      }
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
      viewport.minTemperature,
      viewport.maxTemperature,
    )) {
      final x = geometry
          .offsetFor(
            _ChartPoint(
              temperatureCelsius: temperature,
              relativeHumidityPercent: viewport.minHumidity,
            ),
          )
          .dx;
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
          viewport.minTemperature +
          (viewport.maxTemperature - viewport.minTemperature) * i / samples;
      final relativeHumidity =
          Psychrometrics.relativeHumidityForAbsoluteHumidity(
            temperatureCelsius: temperature,
            absoluteHumidityGM3: result.absoluteHumidityGM3,
          );
      final visibleHumidity = relativeHumidity.clamp(
        viewport.minHumidity,
        viewport.maxHumidity,
      );
      final point = geometry.offsetFor(
        _ChartPoint(
          temperatureCelsius: temperature,
          relativeHumidityPercent: visibleHumidity.toDouble(),
        ),
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
      final x = geometry
          .offsetFor(
            _ChartPoint(
              temperatureCelsius: dewPoint,
              relativeHumidityPercent: viewport.minHumidity,
            ),
          )
          .dx;
      final dewPaint = Paint()
        ..color = const Color(0xFFB45309)
        ..strokeWidth = 1.5;
      if (x >= plotRect.left && x <= plotRect.right) {
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
    }

    final activePoint =
        dragPreview ??
        _ChartPoint(
          temperatureCelsius: result.temperatureCelsius,
          relativeHumidityPercent: result.relativeHumidityPercent,
        );
    final currentPoint = geometry.offsetFor(activePoint);
    canvas.drawCircle(
      currentPoint,
      dragPreview == null ? 7 : 8,
      Paint()
        ..color = dragPreview == null
            ? const Color(0xFF4F46E5)
            : const Color(0xFF0F766E),
    );
    canvas.drawCircle(
      currentPoint,
      10,
      Paint()
        ..color = const Color(0xFF4F46E5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (isCurveLocked) {
      canvas.drawCircle(
        currentPoint,
        15,
        Paint()
          ..color = const Color(0xFF0F766E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    _drawText(
      canvas,
      dragPreview == null
          ? 'Aktuell'
          : '${_formatNumber(activePoint.temperatureCelsius)} °C · ${_formatNumber(activePoint.relativeHumidityPercent, decimals: 0)} %',
      Offset(
        (currentPoint.dx + 8).clamp(plotRect.left, plotRect.right - 112),
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
    return oldDelegate.result != result ||
        oldDelegate.viewport != viewport ||
        oldDelegate.dragPreview != dragPreview ||
        oldDelegate.isCurveLocked != isCurveLocked ||
        oldDelegate.textStyle != textStyle;
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

String _sourceLabel(WeatherMeasurement measurement) {
  return '${measurement.source.label} · ${measurement.label}';
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
