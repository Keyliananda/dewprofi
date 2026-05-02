import type { FormEvent } from 'react'
import type { User } from '../../api'

type HealthState = 'checking' | 'ok' | 'offline'

type LaunchGateProps = {
  health: HealthState
  user: User | null
  errors: Record<string, string[]>
  message: string
  isSubmitting: boolean
  onSubmit: (event: FormEvent<HTMLFormElement>) => void
  onLogout: () => void
}

export function LaunchGate({
  health,
  user,
  errors,
  message,
  isSubmitting,
  onSubmit,
  onLogout,
}: LaunchGateProps) {
  return (
    <main className="launch-shell">
      <header className="launch-topbar">
        <div>
          <p className="eyebrow">Dewprofi Web</p>
          <h1>Start in Kuerze</h1>
        </div>
        <span className={`status status-${health}`}>{statusLabel(health)}</span>
      </header>

      <section className="launch-grid">
        <div className="launch-copy">
          <p className="launch-kicker">Geschlossener Vorabzugang</p>
          <h2>Der Feuchte-Rechner wird vorbereitet.</h2>
          <p>
            Bestehende Konten koennen sich anmelden. Der Produktbereich bleibt bis
            zum Release gesperrt.
          </p>
        </div>

        {user ? (
          <section className="panel launch-panel">
            <p className="eyebrow">Angemeldet</p>
            <h2>{user.name}</h2>
            <p className="muted">{user.email}</p>
            <div className="release-note">
              <strong>Workspace noch gesperrt</strong>
              <span>Der Zugriff wird zum offiziellen Release freigeschaltet.</span>
            </div>
            <button
              className="secondary-action"
              type="button"
              onClick={onLogout}
              disabled={isSubmitting}
            >
              Logout
            </button>
            {message && <p className="message">{message}</p>}
          </section>
        ) : (
          <section className="panel launch-panel">
            <p className="eyebrow">Login</p>
            <h2>Zugang pruefen</h2>
            <form className="launch-form" onSubmit={onSubmit} noValidate>
              <LaunchField
                label="E-Mail"
                name="email"
                type="email"
                autoComplete="email"
                errors={errors.email}
              />
              <LaunchField
                label="Passwort"
                name="password"
                type="password"
                autoComplete="current-password"
                errors={errors.password}
              />
              <button className="primary-action" type="submit" disabled={isSubmitting}>
                Einloggen
              </button>
            </form>
            {message && <p className="message">{message}</p>}
          </section>
        )}
      </section>
    </main>
  )
}

function LaunchField({
  label,
  name,
  type,
  autoComplete,
  errors,
}: {
  label: string
  name: string
  type: string
  autoComplete: string
  errors?: string[]
}) {
  return (
    <label className="field">
      <span>{label}</span>
      <span className="input-shell">
        <input name={name} type={type} autoComplete={autoComplete} />
      </span>
      {errors?.map((fieldError) => (
        <small className="field-error" key={fieldError}>
          {fieldError}
        </small>
      ))}
    </label>
  )
}

function statusLabel(health: HealthState) {
  if (health === 'checking') {
    return 'API pruefen'
  }

  return health === 'ok' ? 'API online' : 'API offline'
}
