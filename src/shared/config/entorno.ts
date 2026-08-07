/**
 * Lectura y validación de las variables de entorno del cliente.
 *
 * Existe por la regla 3 de CLAUDE.md: la `service_role` key vive solo en Edge Functions,
 * jamás en el cliente ni en un `.env` que llegue al bundle. Confiar en que nadie la pegue
 * por error no es un control; esto sí lo es, y falla al arrancar en vez de en producción.
 */

export interface Entorno {
  readonly supabaseUrl: string
  readonly supabaseAnonKey: string
}

export class EntornoInvalidoError extends Error {
  readonly motivos: readonly string[]

  constructor(motivos: readonly string[]) {
    super(
      `Configuración de entorno inválida:\n${motivos.map((m) => `  · ${m}`).join('\n')}\n` +
        'Revisa tu .env local contra .env.example.',
    )
    this.name = 'EntornoInvalidoError'
    this.motivos = motivos
  }
}

/** Prefijo de las claves secretas de Supabase en el formato nuevo. */
const PREFIJO_CLAVE_SECRETA = 'sb_secret_'

/** Decodifica el payload de un JWT, o `null` si no lo es. */
function payloadDeJwt(valor: string): Record<string, unknown> | null {
  const partes = valor.split('.')
  if (partes.length !== 3) return null

  const payload = partes[1]
  if (!payload) return null

  try {
    const base64 = payload.replace(/-/g, '+').replace(/_/g, '/')
    const json = atob(base64.padEnd(Math.ceil(base64.length / 4) * 4, '='))
    const decodificado: unknown = JSON.parse(json)
    return typeof decodificado === 'object' && decodificado !== null
      ? (decodificado as Record<string, unknown>)
      : null
  } catch {
    return null
  }
}

/**
 * Detecta una clave con privilegios de servicio, en los dos formatos que emite Supabase:
 * el JWT heredado (con `role: "service_role"`) y el formato nuevo `sb_secret_…`.
 */
export function esClaveDeServicio(clave: string): boolean {
  if (clave.startsWith(PREFIJO_CLAVE_SECRETA)) return true
  return payloadDeJwt(clave)?.['role'] === 'service_role'
}

/**
 * Valida la configuración y devuelve el entorno tipado.
 *
 * Acumula todos los motivos antes de fallar: descubrir los errores de configuración de
 * uno en uno es una forma lenta de perder una tarde.
 *
 * @throws {EntornoInvalidoError}
 */
export function leerEntorno(fuente: Record<string, string | undefined>): Entorno {
  const motivos: string[] = []

  const url = fuente['VITE_SUPABASE_URL']?.trim() ?? ''
  const anonKey = fuente['VITE_SUPABASE_ANON_KEY']?.trim() ?? ''

  if (url === '') {
    motivos.push('falta VITE_SUPABASE_URL')
  } else if (!/^https?:\/\/.+/.test(url)) {
    motivos.push(`VITE_SUPABASE_URL no es una URL http(s): "${url}"`)
  }

  if (anonKey === '') {
    motivos.push('falta VITE_SUPABASE_ANON_KEY')
  } else if (esClaveDeServicio(anonKey)) {
    motivos.push(
      'VITE_SUPABASE_ANON_KEY contiene una clave de servicio. Esa clave ignora las políticas ' +
        'RLS y solo puede vivir en Edge Functions (CLAUDE.md, regla 3). Usa la clave anon.',
    )
  }

  if (motivos.length > 0) throw new EntornoInvalidoError(motivos)

  return { supabaseUrl: url, supabaseAnonKey: anonKey }
}
