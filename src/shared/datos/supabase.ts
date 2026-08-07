import { createClient, type SupabaseClient } from '@supabase/supabase-js'

import { leerEntorno } from '../config/entorno.ts'
import type { Database } from './tipos-supabase.ts'

/**
 * Cliente de datos tipado contra el esquema.
 *
 * Usa la clave `anon`, y eso es correcto: la seguridad no está en esconder la clave sino
 * en las políticas RLS (docs/plan.md 5.2). `leerEntorno` se encarga de que aquí no acabe
 * por error una clave con privilegios de servicio.
 *
 * El tipo `Database` sale de tipos-supabase.ts, que se regenera con `npm run db:tipos`.
 * Mientras el esquema esté vacío el tipado no aporta nada; a partir del encargo 02 es lo
 * que hace que una consulta a una columna que no existe falle en `npm run typecheck` y no
 * en producción.
 */
export type ClienteEduAcceso = SupabaseClient<Database>

let cliente: ClienteEduAcceso | undefined

/**
 * Devuelve el cliente compartido, creándolo la primera vez.
 *
 * Es perezoso a propósito: si se creara al importar el módulo, cualquier archivo que lo
 * toque —incluida una prueba que no habla con la base— reventaría por configuración
 * ausente.
 *
 * @throws {import('../config/entorno.ts').EntornoInvalidoError} si falta configuración.
 */
export function obtenerCliente(): ClienteEduAcceso {
  cliente ??= crearCliente(import.meta.env as unknown as Record<string, string | undefined>)
  return cliente
}

/** Crea un cliente nuevo a partir de una configuración concreta. Útil en pruebas. */
export function crearCliente(fuente: Record<string, string | undefined>): ClienteEduAcceso {
  const entorno = leerEntorno(fuente)

  return createClient<Database>(entorno.supabaseUrl, entorno.supabaseAnonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      // El portal no usa enlaces de recuperación en la URL (ver docs/adr/0003).
      detectSessionInUrl: false,
    },
  })
}
