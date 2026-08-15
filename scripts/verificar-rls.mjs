#!/usr/bin/env node
/**
 * `test:rls` — pruebas de aislamiento y de esquema, en pgTAP.
 *
 * Sustituye al marcador de posición del encargo 01. Aquel salía verde mientras no hubiera
 * migraciones y se ponía en rojo solo en cuanto apareció la primera; este es el runner de
 * verdad.
 *
 * Es "la prueba que no es negociable" de docs/plan.md 5.3: sin ella la RLS se degrada en
 * silencio — alguien añade una tabla, olvida la política, y nadie se entera hasta que un
 * estudiante ve las notas de otro.
 *
 * Requiere la base local levantada (`supabase start`).
 */
import { spawnSync } from 'node:child_process'
import { readdirSync } from 'node:fs'
import { join } from 'node:path'
import { exit } from 'node:process'

const raiz = process.cwd()

const archivosSql = (directorio) => {
  try {
    return readdirSync(join(raiz, ...directorio)).filter((archivo) => archivo.endsWith('.sql'))
  } catch {
    return []
  }
}

const migraciones = archivosSql(['supabase', 'migrations'])
const pruebas = archivosSql(['supabase', 'tests']).filter((archivo) =>
  archivo.endsWith('.test.sql'),
)

// `supabase test db` sale en verde con cero archivos de prueba. Sin esta guarda, borrar la
// carpeta de pruebas dejaría `verify` en verde y el sistema sin red de seguridad.
if (migraciones.length > 0 && pruebas.length === 0) {
  console.error(
    `\n  Hay ${migraciones.length} migración(es) y ningún archivo en supabase/tests/.\n` +
      '  Un esquema sin pruebas de aislamiento no puede darse por seguro.\n' +
      '  Ver docs/encargos/02-esquema-y-rls.md, punto 6.\n',
  )
  exit(1)
}

if (pruebas.length === 0) {
  console.error('\n  No hay pruebas que ejecutar y tampoco migraciones. Algo va mal.\n')
  exit(1)
}

const resultado = spawnSync('supabase', ['test', 'db'], {
  stdio: 'inherit',
  shell: process.platform === 'win32',
})

if (resultado.error) {
  console.error(
    `\n  No se pudo ejecutar el CLI de Supabase: ${resultado.error.message}\n` +
      '  Instálalo, o levanta la base con `supabase start` si ya lo tienes.\n',
  )
  exit(1)
}

if (resultado.status !== 0) {
  console.error(
    '\n  Fallaron las pruebas de aislamiento.\n' +
      '  Si alguna consulta devolvió filas que no debería, la política está mal escrita:\n' +
      '  arréglala. Nunca desactives la RLS ni uses la service_role key para que pase\n' +
      '  (CLAUDE.md, regla 2 — es el atajo que deja el sistema abierto).\n',
  )
  exit(resultado.status ?? 1)
}

console.log(`\ntest:rls · ${pruebas.length} archivo(s) de prueba en verde.\n`)
