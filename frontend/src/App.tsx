import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import './App.css'
import { ApiError, apiGet, apiPost } from './api'
import type { User } from './api'
import { LaunchGate } from './features/launchGate/LaunchGate'

const RELEASE_WORKSPACE = import.meta.env.VITE_RELEASE_WORKSPACE === 'true'
const FLUTTER_APP_URL =
  import.meta.env.VITE_FLUTTER_APP_URL?.trim() || '/flutter/index.html'

type HealthState = 'checking' | 'ok' | 'offline'
type HealthResponse = { status: string }
type AuthResponse = { user: User }

function App() {
  const [health, setHealth] = useState<HealthState>('checking')
  const [user, setUser] = useState<User | null>(null)
  const [authMessage, setAuthMessage] = useState('')
  const [authErrors, setAuthErrors] = useState<Record<string, string[]>>({})
  const [isAuthSubmitting, setIsAuthSubmitting] = useState(false)
  const workspaceUnlocked =
    user?.is_super_admin === true || (RELEASE_WORKSPACE && user !== null)

  useEffect(() => {
    apiGet<HealthResponse>('/api/health')
      .then((response) => setHealth(response.status === 'ok' ? 'ok' : 'offline'))
      .catch(() => setHealth('offline'))

    apiGet<AuthResponse>('/api/me')
      .then((response) => setUser(response.user))
      .catch(() => setUser(null))
  }, [])

  async function submitLogin(event: FormEvent<HTMLFormElement>) {
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

  if (!workspaceUnlocked) {
    return (
      <LaunchGate
        health={health}
        user={user}
        errors={authErrors}
        message={authMessage}
        isSubmitting={isAuthSubmitting}
        onSubmit={submitLogin}
        onLogout={logout}
      />
    )
  }

  return (
    <FlutterWorkspace
      health={health}
      user={user}
      appUrl={FLUTTER_APP_URL}
      isSubmitting={isAuthSubmitting}
      onLogout={logout}
    />
  )
}

function FlutterWorkspace({
  health,
  user,
  appUrl,
  isSubmitting,
  onLogout,
}: {
  health: HealthState
  user: User | null
  appUrl: string
  isSubmitting: boolean
  onLogout: () => void
}) {
  const frameTitle = useMemo(() => 'Dewprofi Flutter App', [])

  return (
    <main className="flutter-shell">
      <header className="flutter-topbar">
        <div>
          <p className="eyebrow">Dewprofi App</p>
          <h1>Workspace</h1>
        </div>
        <div className="topbar-actions">
          <span className={`status status-${health}`}>{statusLabel(health)}</span>
          {user && <span className="user-pill">{user.name}</span>}
          <button
            className="secondary-action topbar-button"
            type="button"
            onClick={onLogout}
            disabled={isSubmitting}
          >
            Logout
          </button>
        </div>
      </header>

      <section className="flutter-frame-panel" aria-label="Dewprofi Flutter App">
        <iframe
          className="flutter-frame"
          src={appUrl}
          title={frameTitle}
          allow="clipboard-read; clipboard-write; geolocation; bluetooth"
        />
      </section>
    </main>
  )
}

function statusLabel(health: HealthState) {
  if (health === 'checking') {
    return 'API pruefen'
  }

  return health === 'ok' ? 'API online' : 'API offline'
}

function messageFromError(error: unknown) {
  if (error instanceof ApiError) {
    return error.message
  }

  return 'Die API ist gerade nicht erreichbar.'
}

export default App
