const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL?.replace(/\/$/, '') ??
  'http://api.dewprofi.test'

export type User = {
  id: number
  name: string
  email: string
}

type ApiErrorBody = {
  message?: string
  errors?: Record<string, string[]>
}

export class ApiError extends Error {
  readonly status: number
  readonly errors: Record<string, string[]>

  constructor(
    message: string,
    status: number,
    errors: Record<string, string[]> = {},
  ) {
    super(message)
    this.status = status
    this.errors = errors
  }
}

export async function apiGet<T>(path: string): Promise<T> {
  return request<T>(path)
}

export async function apiPost<T>(
  path: string,
  body?: Record<string, unknown>,
): Promise<T> {
  await csrfCookie()

  return request<T>(path, {
    method: 'POST',
    body: JSON.stringify(body ?? {}),
    headers: {
      'Content-Type': 'application/json',
      'X-XSRF-TOKEN': xsrfToken(),
    },
  })
}

async function csrfCookie() {
  await fetch(`${API_BASE_URL}/sanctum/csrf-cookie`, {
    credentials: 'include',
  })
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    credentials: 'include',
    headers: {
      Accept: 'application/json',
      ...init.headers,
    },
  })

  const data = (await response.json().catch(() => ({}))) as T & ApiErrorBody

  if (!response.ok) {
    throw new ApiError(
      data.message ?? 'Die Anfrage konnte nicht verarbeitet werden.',
      response.status,
      data.errors,
    )
  }

  return data
}

function xsrfToken() {
  const token = document.cookie
    .split('; ')
    .find((row) => row.startsWith('XSRF-TOKEN='))
    ?.split('=')[1]

  return token ? decodeURIComponent(token) : ''
}
