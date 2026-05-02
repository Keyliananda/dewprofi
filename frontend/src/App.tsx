import { useEffect, useMemo, useRef, useState } from 'react'
import type { FormEvent, PointerEvent, WheelEvent } from 'react'
import './App.css'
import { ApiError, apiGet, apiPost } from './api'
import type { User } from './api'
import { LaunchGate } from './features/launchGate/LaunchGate'

const DEFAULT_PRESSURE_HPA = 1013.25
const RELEASE_WORKSPACE = import.meta.env.VITE_RELEASE_WORKSPACE === 'true'

type HealthResponse = { status: string }
type AuthResponse = { user: User }
type HealthState = 'checking' | 'ok' | 'offline'
type InputMode = 'manual' | 'place' | 'examples'
type DetailMode = 'simple' | 'pro'
type ChartMode = 'none' | 'point' | 'pan'

type Coordinates = {
  latitude: number
  longitude: number
}

type WeatherPlace = {
  name: string
  country: string
  admin1?: string | null
  displayName: string
  coordinates: Coordinates
}

type Measurement = {
  temperatureCelsius: number
  relativeHumidityPercent: number
  pressureHPa: number | null
  source: 'manual' | 'place' | 'examplePlace'
  sourceLabel: string
  label: string
  observedAt: string
  fetchedAt: string
}

type PsychrometricResult = {
  temperatureCelsius: number
  relativeHumidityPercent: number
  pressureHPa: number
  saturationVaporPressureHPa: number
  vaporPressureHPa: number
  absoluteHumidityGM3: number
  dewPointCelsius: number | null
  dewPointSpreadCelsius: number | null
  zone: string
}

type WeatherResponse = {
  measurement: Measurement
  result: PsychrometricResult
}

type Viewport = {
  minTemperature: number
  maxTemperature: number
  minHumidity: number
  maxHumidity: number
}

type ChartPoint = {
  temperatureCelsius: number
  relativeHumidityPercent: number
}

function App() {
  const now = useMemo(() => new Date().toISOString(), [])
  const [health, setHealth] = useState<HealthState>('checking')
  const [user, setUser] = useState<User | null>(null)
  const [authMode, setAuthMode] = useState<'login' | 'register'>('login')
  const [inputMode, setInputMode] = useState<InputMode>('manual')
  const [detailMode, setDetailMode] = useState<DetailMode>('simple')
  const [isInputExpanded, setIsInputExpanded] = useState(false)
  const [isLoadingWeather, setIsLoadingWeather] = useState(false)
  const [weatherMessage, setWeatherMessage] = useState('')
  const [authMessage, setAuthMessage] = useState('')
  const [error, setError] = useState('')
  const [authErrors, setAuthErrors] = useState<Record<string, string[]>>({})
  const [temperatureText, setTemperatureText] = useState('21,0')
  const [humidityText, setHumidityText] = useState('50')
  const [pressureText, setPressureText] = useState('')
  const [placeQuery, setPlaceQuery] = useState('')
  const [places, setPlaces] = useState<WeatherPlace[]>([])
  const [examplePlaces, setExamplePlaces] = useState<WeatherPlace[]>([])
  const [isAuthSubmitting, setIsAuthSubmitting] = useState(false)
  const [measurement, setMeasurement] = useState<Measurement>(() =>
    manualMeasurement(21, 50, null, now),
  )
  const [result, setResult] = useState<PsychrometricResult>(() =>
    calculatePsychrometrics(21, 50, null),
  )

  useEffect(() => {
    apiGet<HealthResponse>('/api/health')
      .then((response) => setHealth(response.status === 'ok' ? 'ok' : 'offline'))
      .catch(() => setHealth('offline'))

    apiGet<AuthResponse>('/api/me')
      .then((response) => setUser(response.user))
      .catch(() => setUser(null))

    if (!RELEASE_WORKSPACE) {
      return
    }

    apiGet<{ places: WeatherPlace[] }>('/api/example-places')
      .then((response) => setExamplePlaces(response.places))
      .catch(() => setWeatherMessage('Beispielorte konnten nicht geladen werden.'))
  }, [])

  function recalculateManual(next?: {
    temperatureText?: string
    humidityText?: string
    pressureText?: string
  }) {
    const nextTemperatureText = next?.temperatureText ?? temperatureText
    const nextHumidityText = next?.humidityText ?? humidityText
    const nextPressureText = next?.pressureText ?? pressureText
    const temperature = parseDecimal(nextTemperatureText)
    const humidity = parseDecimal(nextHumidityText)
    const pressure =
      nextPressureText.trim() === '' ? null : parseDecimal(nextPressureText)

    if (
      temperature === null ||
      humidity === null ||
      (nextPressureText.trim() !== '' && pressure === null)
    ) {
      setError('Bitte Zahlenwerte eingeben.')
      return
    }

    try {
      const calculated = calculatePsychrometrics(temperature, humidity, pressure)
      const timestamp = new Date().toISOString()
      setMeasurement(manualMeasurement(temperature, humidity, pressure, timestamp))
      setResult(calculated)
      setError('')
    } catch (nextError) {
      setError(
        nextError instanceof Error
          ? nextError.message
          : 'Eingaben ausserhalb des Bereichs.',
      )
    }
  }

  function updateTemperature(value: string) {
    setTemperatureText(value)
    recalculateManual({ temperatureText: value })
  }

  function updateHumidity(value: string) {
    setHumidityText(value)
    recalculateManual({ humidityText: value })
  }

  function updatePressure(value: string) {
    setPressureText(value)
    recalculateManual({ pressureText: value })
  }

  function applyChartMeasurement(point: ChartPoint) {
    const temperature = roundToTenth(point.temperatureCelsius)
    const humidity = roundToWhole(point.relativeHumidityPercent)
    const nextTemperatureText = formatNumber(temperature)
    const nextHumidityText = String(humidity)
    setInputMode('manual')
    setTemperatureText(nextTemperatureText)
    setHumidityText(nextHumidityText)
    setWeatherMessage('Diagrammwert uebernommen.')
    recalculateManual({
      temperatureText: nextTemperatureText,
      humidityText: nextHumidityText,
    })
  }

  async function searchPlaces(event?: FormEvent) {
    event?.preventDefault()
    const query = placeQuery.trim()
    if (query.length < 2) {
      setWeatherMessage('Bitte mindestens zwei Zeichen eingeben.')
      return
    }

    setIsLoadingWeather(true)
    setWeatherMessage('')
    try {
      const response = await apiGet<{ places: WeatherPlace[] }>(
        `/api/places?query=${encodeURIComponent(query)}`,
      )
      setPlaces(response.places)
      if (response.places[0]) {
        await loadWeather(response.places[0], 'place')
      }
    } catch (nextError) {
      setWeatherMessage(messageFromError(nextError))
      setInputMode('manual')
      recalculateManual()
    } finally {
      setIsLoadingWeather(false)
    }
  }

  async function loadWeather(place: WeatherPlace, source: 'place' | 'examplePlace') {
    setIsLoadingWeather(true)
    setWeatherMessage('')
    try {
      const params = new URLSearchParams({
        latitude: String(place.coordinates.latitude),
        longitude: String(place.coordinates.longitude),
        label: place.displayName,
        source,
      })
      const response = await apiGet<WeatherResponse>(`/api/weather?${params}`)
      setMeasurement(response.measurement)
      setResult(response.result)
      setTemperatureText(formatNumber(response.measurement.temperatureCelsius))
      setHumidityText(String(Math.round(response.measurement.relativeHumidityPercent)))
      setPressureText(
        response.measurement.pressureHPa === null
          ? ''
          : formatNumber(response.measurement.pressureHPa, 1),
      )
      setError('')
      setInputMode(source === 'place' ? 'place' : 'examples')
      setWeatherMessage(`${response.measurement.label} geladen.`)
    } catch (nextError) {
      setWeatherMessage(messageFromError(nextError))
      setInputMode('manual')
      recalculateManual()
    } finally {
      setIsLoadingWeather(false)
    }
  }

  async function submitAuth(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setIsAuthSubmitting(true)
    setAuthMessage('')
    setAuthErrors({})

    try {
      const payload = Object.fromEntries(new FormData(event.currentTarget).entries())
      const response = await apiPost<AuthResponse>(
        authMode === 'login' ? '/api/login' : '/api/register',
        payload,
      )
      setUser(response.user)
      setAuthMessage(authMode === 'login' ? 'Angemeldet.' : 'Konto erstellt.')
    } catch (nextError) {
      if (nextError instanceof ApiError) {
        setAuthMessage(nextError.message)
        setAuthErrors(nextError.errors)
      } else {
        setAuthMessage('Die API ist gerade nicht erreichbar.')
      }
    } finally {
      setIsAuthSubmitting(false)
    }
  }

  async function submitLaunchLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setIsAuthSubmitting(true)
    setAuthMessage('')
    setAuthErrors({})

    try {
      const payload = Object.fromEntries(new FormData(event.currentTarget).entries())
      const response = await apiPost<AuthResponse>('/api/login', payload)
      setUser(response.user)
      setAuthMessage('Angemeldet.')
    } catch (nextError) {
      if (nextError instanceof ApiError) {
        setAuthMessage(nextError.message)
        setAuthErrors(nextError.errors)
      } else {
        setAuthMessage('Die API ist gerade nicht erreichbar.')
      }
    } finally {
      setIsAuthSubmitting(false)
    }
  }

  async function logout() {
    setIsAuthSubmitting(true)
    setAuthMessage('')
    try {
      await apiPost('/api/logout')
      setUser(null)
      setAuthMessage('Abgemeldet.')
    } catch (nextError) {
      setAuthMessage(messageFromError(nextError))
    } finally {
      setIsAuthSubmitting(false)
    }
  }

  if (!RELEASE_WORKSPACE) {
    return (
      <LaunchGate
        health={health}
        user={user}
        errors={authErrors}
        message={authMessage}
        isSubmitting={isAuthSubmitting}
        onSubmit={submitLaunchLogin}
        onLogout={logout}
      />
    )
  }

  return (
    <main className="app-shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">Dewprofi Web</p>
          <h1>Feuchte-Rechner</h1>
        </div>
        <div className="topbar-actions">
          <span className={`status status-${health}`}>
            {health === 'checking'
              ? 'API pruefen'
              : health === 'ok'
                ? 'API online'
                : 'API offline'}
          </span>
          {user && <span className="user-pill">{user.name}</span>}
        </div>
      </header>

      <section className="workspace">
        <aside className="side-stack">
          <InputPanel
            inputMode={inputMode}
            isExpanded={isInputExpanded}
            isLoadingWeather={isLoadingWeather}
            measurement={measurement}
            result={result}
            temperatureText={temperatureText}
            humidityText={humidityText}
            pressureText={pressureText}
            placeQuery={placeQuery}
            places={places}
            examplePlaces={examplePlaces}
            weatherMessage={weatherMessage}
            onToggleExpanded={() => setIsInputExpanded((expanded) => !expanded)}
            onInputModeChange={(mode) => {
              setInputMode(mode)
              if (mode === 'manual') {
                recalculateManual()
              }
            }}
            onTemperatureChange={updateTemperature}
            onHumidityChange={updateHumidity}
            onPressureChange={updatePressure}
            onPlaceQueryChange={setPlaceQuery}
            onSearchPlaces={searchPlaces}
            onLoadWeather={loadWeather}
          />
          <AuthPanel
            authMode={authMode}
            user={user}
            errors={authErrors}
            message={authMessage}
            isSubmitting={isAuthSubmitting}
            onAuthModeChange={setAuthMode}
            onSubmit={submitAuth}
            onLogout={logout}
          />
        </aside>

        <section className="result-stack">
          <HumidityChart
            result={result}
            onMeasurementChanged={applyChartMeasurement}
          />
          <ResultPanel
            result={result}
            measurement={measurement}
            detailMode={detailMode}
            error={error}
            onDetailModeChange={setDetailMode}
          />
        </section>
      </section>
    </main>
  )
}

function InputPanel({
  inputMode,
  isExpanded,
  isLoadingWeather,
  measurement,
  result,
  temperatureText,
  humidityText,
  pressureText,
  placeQuery,
  places,
  examplePlaces,
  weatherMessage,
  onToggleExpanded,
  onInputModeChange,
  onTemperatureChange,
  onHumidityChange,
  onPressureChange,
  onPlaceQueryChange,
  onSearchPlaces,
  onLoadWeather,
}: {
  inputMode: InputMode
  isExpanded: boolean
  isLoadingWeather: boolean
  measurement: Measurement
  result: PsychrometricResult
  temperatureText: string
  humidityText: string
  pressureText: string
  placeQuery: string
  places: WeatherPlace[]
  examplePlaces: WeatherPlace[]
  weatherMessage: string
  onToggleExpanded: () => void
  onInputModeChange: (mode: InputMode) => void
  onTemperatureChange: (value: string) => void
  onHumidityChange: (value: string) => void
  onPressureChange: (value: string) => void
  onPlaceQueryChange: (value: string) => void
  onSearchPlaces: (event?: FormEvent) => void
  onLoadWeather: (place: WeatherPlace, source: 'place' | 'examplePlace') => void
}) {
  return (
    <section className="panel input-panel">
      <button className="compact-row" type="button" onClick={onToggleExpanded}>
        <span>
          <strong>
            {formatNumber(result.temperatureCelsius)} °C ·{' '}
            {formatNumber(result.relativeHumidityPercent, 0)} %
          </strong>
          <small>
            {measurement.sourceLabel} · {measurement.label}
          </small>
        </span>
        <span aria-hidden="true">{isExpanded ? '⌃' : '⌄'}</span>
      </button>

      {isExpanded && (
        <div className="expanded-input">
          <SegmentedControl
            value={inputMode}
            options={[
              ['manual', 'Manuell'],
              ['place', 'Ort'],
              ['examples', 'Beispiele'],
            ]}
            onChange={onInputModeChange}
          />

          {inputMode === 'place' && (
            <form className="place-search" onSubmit={onSearchPlaces}>
              <Field
                label="Ort suchen"
                name="place"
                type="text"
                autoComplete="address-level2"
                value={placeQuery}
                onChange={onPlaceQueryChange}
              />
              <button className="primary-action" type="submit" disabled={isLoadingWeather}>
                Wetter laden
              </button>
              {places.length > 0 && (
                <div className="chip-row">
                  {places.map((place) => (
                    <button
                      key={`${place.displayName}-${place.coordinates.latitude}`}
                      type="button"
                      className="chip"
                      onClick={() => onLoadWeather(place, 'place')}
                    >
                      {place.name}
                    </button>
                  ))}
                </div>
              )}
            </form>
          )}

          {inputMode === 'examples' && (
            <div className="chip-row">
              {examplePlaces.map((place) => (
                <button
                  key={place.displayName}
                  type="button"
                  className="chip"
                  disabled={isLoadingWeather}
                  onClick={() => onLoadWeather(place, 'examplePlace')}
                >
                  {place.name}
                </button>
              ))}
            </div>
          )}

          {weatherMessage && <p className="message">{weatherMessage}</p>}

          <div className="manual-grid">
            <Field
              label="Temperatur"
              name="temperature"
              type="text"
              autoComplete="off"
              suffix="°C"
              value={temperatureText}
              onChange={onTemperatureChange}
            />
            <Field
              label="Relative Luftfeuchte"
              name="humidity"
              type="text"
              autoComplete="off"
              suffix="%"
              value={humidityText}
              onChange={onHumidityChange}
            />
            <Field
              label="Luftdruck optional"
              name="pressure"
              type="text"
              autoComplete="off"
              suffix="hPa"
              value={pressureText}
              onChange={onPressureChange}
            />
          </div>
          <p className="muted">
            Default: {formatNumber(DEFAULT_PRESSURE_HPA, 2)} hPa
          </p>
        </div>
      )}
    </section>
  )
}

function ResultPanel({
  result,
  measurement,
  detailMode,
  error,
  onDetailModeChange,
}: {
  result: PsychrometricResult
  measurement: Measurement
  detailMode: DetailMode
  error: string
  onDetailModeChange: (mode: DetailMode) => void
}) {
  if (error) {
    return <section className="panel error-panel">{error}</section>
  }

  return (
    <section className="panel result-panel">
      <div className="result-head">
        <div>
          <h2>{measurement.label}</h2>
          <p className="muted">{measurementSubtitle(measurement)}</p>
        </div>
        <span className={`zone zone-${result.zone}`}>{result.zone}</span>
        <SegmentedControl
          value={detailMode}
          options={[
            ['simple', 'Einfach'],
            ['pro', 'Profi'],
          ]}
          onChange={onDetailModeChange}
        />
      </div>

      <div className="metric-grid">
        <Metric label="Temperatur" value={`${formatNumber(result.temperatureCelsius)} °C`} />
        <Metric
          label="Relative Feuchte"
          value={`${formatNumber(result.relativeHumidityPercent)} %`}
        />
        <Metric
          label="Taupunkt"
          value={
            result.dewPointCelsius === null
              ? 'unter Messbereich'
              : `${formatNumber(result.dewPointCelsius)} °C`
          }
        />
      </div>

      {detailMode === 'pro' && (
        <>
          <hr />
          <h3>Details</h3>
          <div className="metric-grid">
            <Metric
              label="Absolute Feuchte"
              value={`${formatNumber(result.absoluteHumidityGM3)} g/m3`}
            />
            <Metric label="Druck" value={`${formatNumber(result.pressureHPa, 2)} hPa`} />
            <Metric
              label="Saettigungsdampfdruck"
              value={`${formatNumber(result.saturationVaporPressureHPa, 2)} hPa`}
            />
            <Metric
              label="Dampfdruck"
              value={`${formatNumber(result.vaporPressureHPa, 2)} hPa`}
            />
            <Metric
              label="Taupunktabstand"
              value={
                result.dewPointSpreadCelsius === null
                  ? 'nicht bestimmbar'
                  : `${formatNumber(result.dewPointSpreadCelsius)} °C`
              }
            />
            <Metric
              label="Datenalter"
              value={formatAge(new Date(measurement.observedAt))}
            />
            <Metric
              label="Quelle"
              value={`${measurement.sourceLabel} · ${measurement.label}`}
            />
          </div>
        </>
      )}
    </section>
  )
}

function HumidityChart({
  result,
  onMeasurementChanged,
}: {
  result: PsychrometricResult
  onMeasurementChanged: (point: ChartPoint) => void
}) {
  const svgRef = useRef<SVGSVGElement | null>(null)
  const [manualViewport, setManualViewport] = useState<Viewport | null>(null)
  const [curveLocked, setCurveLocked] = useState(false)
  const [interaction, setInteraction] = useState<{
    mode: ChartMode
    pointId: number
    startPoint: ChartPoint
    startViewport: Viewport
  } | null>(null)

  const viewport = manualViewport ?? autoViewportFor(result)
  const curvePath = useMemo(() => humidityCurvePath(result, viewport), [result, viewport])
  const currentPoint = {
    temperatureCelsius: result.temperatureCelsius,
    relativeHumidityPercent: result.relativeHumidityPercent,
  }
  const dewPoint =
    result.dewPointCelsius === null
      ? null
      : { temperatureCelsius: result.dewPointCelsius, relativeHumidityPercent: 100 }
  const currentSvg = chartToSvg(currentPoint, viewport)
  const dewSvg = dewPoint ? chartToSvg(dewPoint, viewport) : null

  function pointerPoint(event: PointerEvent<SVGSVGElement>) {
    const rect = svgRef.current?.getBoundingClientRect()
    if (!rect) {
      return { x: 0, y: 0 }
    }
    return {
      x: ((event.clientX - rect.left) / rect.width) * 720,
      y: ((event.clientY - rect.top) / rect.height) * 320,
    }
  }

  function handlePointerDown(event: PointerEvent<SVGSVGElement>) {
    const svgPoint = pointerPoint(event)
    const distance = Math.hypot(svgPoint.x - currentSvg.x, svgPoint.y - currentSvg.y)
    const point = svgToChart(svgPoint, viewport)
    setInteraction({
      mode: distance <= 24 ? 'point' : 'pan',
      pointId: event.pointerId,
      startPoint: point,
      startViewport: viewport,
    })
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  function handlePointerMove(event: PointerEvent<SVGSVGElement>) {
    if (!interaction || interaction.pointId !== event.pointerId) {
      return
    }

    const point = svgToChart(pointerPoint(event), interaction.startViewport)
    if (interaction.mode === 'point') {
      if (curveLocked) {
        const humidity = relativeHumidityForAbsoluteHumidity(
          point.temperatureCelsius,
          result.absoluteHumidityGM3,
        )
        onMeasurementChanged({
          temperatureCelsius: point.temperatureCelsius,
          relativeHumidityPercent: clamp(humidity, 0, 100),
        })
        return
      }
      onMeasurementChanged({
        temperatureCelsius: point.temperatureCelsius,
        relativeHumidityPercent: clamp(point.relativeHumidityPercent, 0, 100),
      })
      return
    }

    const deltaTemperature =
      interaction.startPoint.temperatureCelsius - point.temperatureCelsius
    const deltaHumidity =
      interaction.startPoint.relativeHumidityPercent - point.relativeHumidityPercent
    setManualViewport(
      normalizeViewport({
        minTemperature: interaction.startViewport.minTemperature + deltaTemperature,
        maxTemperature: interaction.startViewport.maxTemperature + deltaTemperature,
        minHumidity: interaction.startViewport.minHumidity + deltaHumidity,
        maxHumidity: interaction.startViewport.maxHumidity + deltaHumidity,
      }),
    )
  }

  function handleWheel(event: WheelEvent<SVGSVGElement>) {
    event.preventDefault()
    const focalPoint = svgToChart(
      {
        x:
          ((event.clientX - event.currentTarget.getBoundingClientRect().left) /
            event.currentTarget.getBoundingClientRect().width) *
          720,
        y:
          ((event.clientY - event.currentTarget.getBoundingClientRect().top) /
            event.currentTarget.getBoundingClientRect().height) *
          320,
      },
      viewport,
    )
    const factor = event.deltaY < 0 ? 1.15 : 0.87
    setManualViewport(normalizeViewport(zoomViewport(viewport, focalPoint, factor)))
  }

  return (
    <section className="panel chart-panel">
      <div className="chart-head">
        <h2>Temperatur-Feuchte-Grafik</h2>
        <div className="icon-actions">
          <button
            type="button"
            className={curveLocked ? 'icon-button active' : 'icon-button'}
            onClick={() => setCurveLocked((locked) => !locked)}
            title="Kurvensperre"
          >
            {curveLocked ? '🔒' : '🔓'}
          </button>
          <button
            type="button"
            className="icon-button"
            disabled={manualViewport === null}
            onClick={() => setManualViewport(null)}
            title="Ansicht zuruecksetzen"
          >
            ↺
          </button>
        </div>
      </div>
      <svg
        ref={svgRef}
        className="humidity-chart"
        viewBox="0 0 720 320"
        role="img"
        aria-label="Temperatur-Feuchte-Grafik"
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={() => setInteraction(null)}
        onPointerCancel={() => setInteraction(null)}
        onWheel={handleWheel}
      >
        <rect x="0" y="0" width="720" height="320" rx="8" />
        <ChartBands viewport={viewport} />
        <g className="grid-lines">
          {[0, 25, 50, 75, 100].map((humidity) => {
            const y = chartToSvg({ temperatureCelsius: viewport.minTemperature, relativeHumidityPercent: humidity }, viewport).y
            return <line key={humidity} x1="44" x2="700" y1={y} y2={y} />
          })}
        </g>
        <path className="humidity-curve" d={curvePath} />
        {dewSvg && (
          <g className="dew-point">
            <line x1={dewSvg.x} x2={dewSvg.x} y1="20" y2="278" />
            <circle cx={dewSvg.x} cy={dewSvg.y} r="6" />
          </g>
        )}
        <g className="current-point">
          <circle cx={currentSvg.x} cy={currentSvg.y} r="10" />
          <text x={currentSvg.x + 14} y={currentSvg.y - 12}>
            {formatNumber(result.temperatureCelsius)} °C ·{' '}
            {formatNumber(result.relativeHumidityPercent, 0)} %
          </text>
        </g>
        <text className="axis-label" x="44" y="302">
          {formatNumber(viewport.minTemperature, 0)} °C
        </text>
        <text className="axis-label" x="646" y="302">
          {formatNumber(viewport.maxTemperature, 0)} °C
        </text>
        <text className="axis-label" x="8" y="32">
          100 %
        </text>
        <text className="axis-label" x="18" y="278">
          0 %
        </text>
      </svg>
    </section>
  )
}

function ChartBands({ viewport }: { viewport: Viewport }) {
  return (
    <g className="zone-bands">
      {[
        ['dry', 0, 40],
        ['comfortable', 40, 60],
        ['humid', 60, 70],
        ['critical', 70, 100],
      ].map(([zone, min, max]) => {
        const top = chartToSvg(
          { temperatureCelsius: viewport.minTemperature, relativeHumidityPercent: Number(max) },
          viewport,
        ).y
        const bottom = chartToSvg(
          { temperatureCelsius: viewport.minTemperature, relativeHumidityPercent: Number(min) },
          viewport,
        ).y
        return (
          <rect
            key={zone}
            className={`band-${zone}`}
            x="44"
            y={top}
            width="656"
            height={bottom - top}
          />
        )
      })}
    </g>
  )
}

function AuthPanel({
  authMode,
  user,
  errors,
  message,
  isSubmitting,
  onAuthModeChange,
  onSubmit,
  onLogout,
}: {
  authMode: 'login' | 'register'
  user: User | null
  errors: Record<string, string[]>
  message: string
  isSubmitting: boolean
  onAuthModeChange: (mode: 'login' | 'register') => void
  onSubmit: (event: FormEvent<HTMLFormElement>) => void
  onLogout: () => void
}) {
  return (
    <section className="panel auth-panel">
      <SegmentedControl
        value={authMode}
        options={[
          ['login', 'Login'],
          ['register', 'Registrierung'],
        ]}
        onChange={onAuthModeChange}
      />
      {user ? (
        <div>
          <p className="eyebrow">Session</p>
          <h2>{user.name}</h2>
          <p className="muted">{user.email}</p>
          <button
            className="secondary-action"
            type="button"
            onClick={onLogout}
            disabled={isSubmitting}
          >
            Logout
          </button>
        </div>
      ) : (
        <form onSubmit={onSubmit} noValidate>
          {authMode === 'register' && (
            <Field
              label="Name"
              name="name"
              type="text"
              autoComplete="name"
              errors={errors.name}
            />
          )}
          <Field
            label="E-Mail"
            name="email"
            type="email"
            autoComplete="email"
            errors={errors.email}
          />
          <Field
            label="Passwort"
            name="password"
            type="password"
            autoComplete={authMode === 'login' ? 'current-password' : 'new-password'}
            errors={errors.password}
          />
          {authMode === 'register' && (
            <Field
              label="Passwort bestaetigen"
              name="password_confirmation"
              type="password"
              autoComplete="new-password"
              errors={errors.password_confirmation}
            />
          )}
          <button className="primary-action" type="submit" disabled={isSubmitting}>
            {authMode === 'login' ? 'Einloggen' : 'Konto erstellen'}
          </button>
        </form>
      )}
      {message && <p className="message">{message}</p>}
    </section>
  )
}

function SegmentedControl<T extends string>({
  value,
  options,
  onChange,
}: {
  value: T
  options: [T, string][]
  onChange: (value: T) => void
}) {
  return (
    <div className="segmented-control">
      {options.map(([option, label]) => (
        <button
          key={option}
          type="button"
          className={option === value ? 'active' : ''}
          onClick={() => onChange(option)}
        >
          {label}
        </button>
      ))}
    </div>
  )
}

function Field({
  label,
  name,
  type,
  autoComplete,
  suffix,
  value,
  errors,
  onChange,
}: {
  label: string
  name: string
  type: string
  autoComplete: string
  suffix?: string
  value?: string
  errors?: string[]
  onChange?: (value: string) => void
}) {
  return (
    <label className="field">
      <span>{label}</span>
      <span className="input-shell">
        <input
          name={name}
          type={type}
          autoComplete={autoComplete}
          value={value}
          onChange={(event) => onChange?.(event.target.value)}
        />
        {suffix && <small>{suffix}</small>}
      </span>
      {errors?.map((fieldError) => (
        <small className="field-error" key={fieldError}>
          {fieldError}
        </small>
      ))}
    </label>
  )
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  )
}

function calculatePsychrometrics(
  temperatureCelsius: number,
  relativeHumidityPercent: number,
  pressureHPa: number | null,
): PsychrometricResult {
  if (temperatureCelsius < -80 || temperatureCelsius > 80) {
    throw new Error('Temperatur muss zwischen -80 und 80 °C liegen.')
  }
  if (relativeHumidityPercent < 0 || relativeHumidityPercent > 100) {
    throw new Error('Relative Feuchte muss zwischen 0 und 100 % liegen.')
  }
  const pressure = pressureHPa ?? DEFAULT_PRESSURE_HPA
  if (pressure < 300 || pressure > 1100) {
    throw new Error('Luftdruck muss zwischen 300 und 1100 hPa liegen.')
  }

  const saturationVaporPressureHPa = saturationVaporPressure(temperatureCelsius)
  const vaporPressureHPa =
    saturationVaporPressureHPa * relativeHumidityPercent / 100
  const dewPointCelsius =
    relativeHumidityPercent === 0
      ? null
      : dewPoint(temperatureCelsius, relativeHumidityPercent)
  const absoluteHumidityGM3 =
    216.7 * vaporPressureHPa / (temperatureCelsius + 273.15)
  const dewPointSpreadCelsius =
    dewPointCelsius === null ? null : temperatureCelsius - dewPointCelsius

  return {
    temperatureCelsius,
    relativeHumidityPercent,
    pressureHPa: pressure,
    saturationVaporPressureHPa,
    vaporPressureHPa,
    absoluteHumidityGM3,
    dewPointCelsius,
    dewPointSpreadCelsius,
    zone: classifyHumidity(relativeHumidityPercent, dewPointSpreadCelsius),
  }
}

function manualMeasurement(
  temperatureCelsius: number,
  relativeHumidityPercent: number,
  pressureHPa: number | null,
  timestamp: string,
): Measurement {
  return {
    temperatureCelsius,
    relativeHumidityPercent,
    pressureHPa,
    source: 'manual',
    sourceLabel: 'manuell',
    label: 'Manuelle Eingabe',
    observedAt: timestamp,
    fetchedAt: timestamp,
  }
}

function saturationVaporPressure(temperatureCelsius: number) {
  const constants =
    temperatureCelsius < 0 ? { a: 22.46, b: 272.62 } : { a: 17.62, b: 243.12 }

  return (
    6.112 *
    Math.exp(
      constants.a * temperatureCelsius / (constants.b + temperatureCelsius),
    )
  )
}

function dewPoint(temperatureCelsius: number, relativeHumidityPercent: number) {
  const constants =
    temperatureCelsius < 0 ? { a: 22.46, b: 272.62 } : { a: 17.62, b: 243.12 }
  const gamma =
    Math.log(relativeHumidityPercent / 100) +
    constants.a * temperatureCelsius / (constants.b + temperatureCelsius)
  return constants.b * gamma / (constants.a - gamma)
}

function relativeHumidityForAbsoluteHumidity(
  temperatureCelsius: number,
  absoluteHumidityGM3: number,
) {
  const vaporPressureHPa =
    absoluteHumidityGM3 * (temperatureCelsius + 273.15) / 216.7
  return vaporPressureHPa / saturationVaporPressure(temperatureCelsius) * 100
}

function classifyHumidity(humidity: number, spread: number | null) {
  if (humidity >= 70 || (spread !== null && spread <= 2)) {
    return 'kritisch'
  }
  if (humidity >= 60) {
    return 'feucht'
  }
  if (humidity < 40) {
    return 'trocken'
  }
  return 'angenehm'
}

function autoViewportFor(result: PsychrometricResult): Viewport {
  const dewPointCelsius = result.dewPointCelsius ?? result.temperatureCelsius
  return normalizeViewport({
    minTemperature: Math.floor(
      Math.min(result.temperatureCelsius - 8, dewPointCelsius - 4),
    ),
    maxTemperature: Math.ceil(result.temperatureCelsius + 14),
    minHumidity: 0,
    maxHumidity: 100,
  })
}

function normalizeViewport(viewport: Viewport): Viewport {
  const temperatureSpan = clamp(viewport.maxTemperature - viewport.minTemperature, 6, 80)
  const humiditySpan = clamp(viewport.maxHumidity - viewport.minHumidity, 20, 100)
  const temperatureCenter =
    (viewport.minTemperature + viewport.maxTemperature) / 2
  const humidityCenter = (viewport.minHumidity + viewport.maxHumidity) / 2
  const minTemperature = clamp(temperatureCenter - temperatureSpan / 2, -80, 80 - temperatureSpan)
  const minHumidity = clamp(humidityCenter - humiditySpan / 2, 0, 100 - humiditySpan)

  return {
    minTemperature,
    maxTemperature: minTemperature + temperatureSpan,
    minHumidity,
    maxHumidity: minHumidity + humiditySpan,
  }
}

function zoomViewport(
  viewport: Viewport,
  focalPoint: ChartPoint,
  scaleFactor: number,
): Viewport {
  const temperatureSpan =
    (viewport.maxTemperature - viewport.minTemperature) / scaleFactor
  const humiditySpan = (viewport.maxHumidity - viewport.minHumidity) / scaleFactor
  const xRatio =
    (focalPoint.temperatureCelsius - viewport.minTemperature) /
    (viewport.maxTemperature - viewport.minTemperature)
  const yRatio =
    (focalPoint.relativeHumidityPercent - viewport.minHumidity) /
    (viewport.maxHumidity - viewport.minHumidity)

  return {
    minTemperature: focalPoint.temperatureCelsius - temperatureSpan * xRatio,
    maxTemperature:
      focalPoint.temperatureCelsius + temperatureSpan * (1 - xRatio),
    minHumidity: focalPoint.relativeHumidityPercent - humiditySpan * yRatio,
    maxHumidity:
      focalPoint.relativeHumidityPercent + humiditySpan * (1 - yRatio),
  }
}

function chartToSvg(point: ChartPoint, viewport: Viewport) {
  const plot = { left: 44, top: 20, width: 656, height: 258 }
  return {
    x:
      plot.left +
      (point.temperatureCelsius - viewport.minTemperature) /
        (viewport.maxTemperature - viewport.minTemperature) *
        plot.width,
    y:
      plot.top +
      (1 -
        (point.relativeHumidityPercent - viewport.minHumidity) /
          (viewport.maxHumidity - viewport.minHumidity)) *
        plot.height,
  }
}

function svgToChart(point: { x: number; y: number }, viewport: Viewport) {
  const plot = { left: 44, top: 20, width: 656, height: 258 }
  return {
    temperatureCelsius:
      viewport.minTemperature +
      ((point.x - plot.left) / plot.width) *
        (viewport.maxTemperature - viewport.minTemperature),
    relativeHumidityPercent:
      viewport.minHumidity +
      (1 - (point.y - plot.top) / plot.height) *
        (viewport.maxHumidity - viewport.minHumidity),
  }
}

function humidityCurvePath(result: PsychrometricResult, viewport: Viewport) {
  const points: string[] = []
  for (
    let temperature = viewport.minTemperature;
    temperature <= viewport.maxTemperature;
    temperature += 0.4
  ) {
    const humidity = clamp(
      relativeHumidityForAbsoluteHumidity(
        temperature,
        result.absoluteHumidityGM3,
      ),
      viewport.minHumidity,
      viewport.maxHumidity,
    )
    const svgPoint = chartToSvg(
      { temperatureCelsius: temperature, relativeHumidityPercent: humidity },
      viewport,
    )
    points.push(`${points.length === 0 ? 'M' : 'L'} ${svgPoint.x} ${svgPoint.y}`)
  }
  return points.join(' ')
}

function parseDecimal(value: string) {
  const normalized = value.trim().replace(',', '.')
  if (!normalized) {
    return null
  }
  const parsed = Number(normalized)
  return Number.isFinite(parsed) ? parsed : null
}

function formatNumber(value: number, decimals = 1) {
  return value.toFixed(decimals).replace('.', ',')
}

function formatAge(observedAt: Date) {
  const ageMs = Math.max(0, Date.now() - observedAt.getTime())
  const minutes = Math.floor(ageMs / 60000)
  if (minutes < 1) {
    return 'gerade eben'
  }
  if (minutes < 60) {
    return `${minutes} min`
  }
  return `${Math.floor(minutes / 60)} h`
}

function measurementSubtitle(measurement: Measurement) {
  return `${measurement.sourceLabel} · aktualisiert ${formatClock(
    new Date(measurement.fetchedAt),
  )}`
}

function formatClock(value: Date) {
  return value.toLocaleTimeString('de-DE', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

function messageFromError(error: unknown) {
  if (error instanceof ApiError) {
    return error.message
  }
  return 'Die API ist gerade nicht erreichbar.'
}

function roundToTenth(value: number) {
  return Math.round(value * 10) / 10
}

function roundToWhole(value: number) {
  return Math.round(value)
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value))
}

export default App
