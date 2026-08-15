import { describe, expect, it } from 'vitest'

import { EntornoInvalidoError, esClaveDeServicio, leerEntorno } from './entorno.ts'

/**
 * Arma un JWT de mentira con el `role` pedido. No es una credencial: no va firmado.
 *
 * El payload se codifica en UTF-8 antes de pasar por base64, que es lo que hace un emisor
 * real. Si se usara `btoa(JSON.stringify(...))` a secas, un acento saldría en Latin-1 y la
 * prueba de acentos validaría algo que no ocurre en producción.
 */
function jwtDePrueba(rol: string, extra: Record<string, unknown> = {}): string {
  const base64url = (objeto: unknown) => {
    const bytes = new TextEncoder().encode(JSON.stringify(objeto))
    return btoa(String.fromCharCode(...bytes))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '')
  }

  return [
    base64url({ alg: 'HS256', typ: 'JWT' }),
    base64url({ iss: 'supabase', role: rol, ...extra }),
    'firma-irrelevante-para-esta-prueba',
  ].join('.')
}

/** Ejecuta `accion` y devuelve lo que lanzó. Falla si no lanzó nada. */
function capturarError(accion: () => unknown): unknown {
  try {
    accion()
  } catch (error) {
    return error
  }
  throw new Error('se esperaba que la acción lanzara un error, y no lanzó')
}

const CLAVE_ANON = jwtDePrueba('anon')
const ENTORNO_VALIDO = {
  VITE_SUPABASE_URL: 'http://127.0.0.1:54321',
  VITE_SUPABASE_ANON_KEY: CLAVE_ANON,
}

describe('leerEntorno', () => {
  it('devuelve el entorno tipado cuando la configuración es correcta', () => {
    expect(leerEntorno(ENTORNO_VALIDO)).toEqual({
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseAnonKey: CLAVE_ANON,
    })
  })

  it('ignora los espacios sobrantes al pegar valores', () => {
    const entorno = leerEntorno({
      VITE_SUPABASE_URL: '  http://127.0.0.1:54321  ',
      VITE_SUPABASE_ANON_KEY: `  ${CLAVE_ANON}  `,
    })
    expect(entorno.supabaseUrl).toBe('http://127.0.0.1:54321')
  })

  it('acumula todos los motivos en un solo error, no falla de uno en uno', () => {
    // Se captura el error en vez de usar try/catch: un catch sin assertions previas
    // pasa en silencio el día que la función deja de lanzar.
    const error = capturarError(() => leerEntorno({}))

    expect(error).toBeInstanceOf(EntornoInvalidoError)
    expect((error as EntornoInvalidoError).motivos).toEqual([
      'falta VITE_SUPABASE_URL',
      'falta VITE_SUPABASE_ANON_KEY',
    ])
  })

  it('rechaza una URL que no es http(s)', () => {
    expect(() => leerEntorno({ ...ENTORNO_VALIDO, VITE_SUPABASE_URL: 'localhost:54321' })).toThrow(
      /no es una URL http/,
    )
  })

  it('trata una variable vacía igual que una ausente', () => {
    expect(() => leerEntorno({ ...ENTORNO_VALIDO, VITE_SUPABASE_ANON_KEY: '   ' })).toThrow(
      /falta VITE_SUPABASE_ANON_KEY/,
    )
  })

  // CLAUDE.md, regla 3: la service_role key jamás llega al cliente.
  it('rechaza un JWT de service_role puesto en la clave anon', () => {
    expect(() =>
      leerEntorno({ ...ENTORNO_VALIDO, VITE_SUPABASE_ANON_KEY: jwtDePrueba('service_role') }),
    ).toThrow(/clave de servicio/)
  })

  it('rechaza una clave secreta en el formato nuevo sb_secret_', () => {
    expect(() =>
      leerEntorno({ ...ENTORNO_VALIDO, VITE_SUPABASE_ANON_KEY: 'sb_secret_abc123' }),
    ).toThrow(/clave de servicio/)
  })

  // Sin esto la comprobación de service_role fallaría hacia el lado permisivo: un token
  // ilegible pasaría como si fuera una clave anon legítima.
  it('rechaza un token con forma de JWT cuyo contenido no se puede leer', () => {
    expect(() => leerEntorno({ ...ENTORNO_VALIDO, VITE_SUPABASE_ANON_KEY: 'aaa.bbb.ccc' })).toThrow(
      /no se puede leer/,
    )
  })

  it('acepta un JWT con acentos en el payload en vez de reventar al decodificarlo', () => {
    const conAcentos = jwtDePrueba('anon', { nombre: 'Coordinación Puerto López' })
    expect(
      leerEntorno({ ...ENTORNO_VALIDO, VITE_SUPABASE_ANON_KEY: conAcentos }).supabaseAnonKey,
    ).toBe(conAcentos)
  })
})

describe('esClaveDeServicio', () => {
  it('reconoce las dos formas de clave privilegiada', () => {
    expect(esClaveDeServicio(jwtDePrueba('service_role'))).toBe(true)
    expect(esClaveDeServicio('sb_secret_loquesea')).toBe(true)
  })

  it('no marca como privilegiadas las claves públicas', () => {
    expect(esClaveDeServicio(CLAVE_ANON)).toBe(false)
    expect(esClaveDeServicio('sb_publishable_abc123')).toBe(false)
  })

  it('no revienta con basura que no es un JWT', () => {
    expect(esClaveDeServicio('')).toBe(false)
    expect(esClaveDeServicio('a.b.c')).toBe(false)
    expect(esClaveDeServicio('no-tiene-puntos')).toBe(false)
  })
})
