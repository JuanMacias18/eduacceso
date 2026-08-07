#!/usr/bin/env node
/**
 * `test:rls` — marcador de posición con trinquete.
 *
 * El encargo 01 exige que `npm run verify` exista y salga en verde desde el primer día,
 * aunque varios de sus pasos todavía no prueben nada (ver docs/AGENT_LOOP.md). El riesgo
 * evidente es que un marcador que devuelve verde se quede verde para siempre y la prueba
 * de aislamiento —la que docs/plan.md 5.3 llama "no negociable"— no se escriba nunca.
 *
 * Por eso esto no es un `exit 0` incondicional:
 *
 *   · Sin migraciones  → verde. No hay datos que aislar todavía.
 *   · Con migraciones  → rojo. Existe esquema, luego existe algo que puede filtrarse,
 *                        y este script tiene que haber sido reemplazado por las pruebas
 *                        reales del encargo 02.
 *
 * Dicho de otro modo: se autodestruye exactamente cuando empieza el encargo 02.
 */
import { readdirSync } from 'node:fs'
import { join } from 'node:path'
import { exit } from 'node:process'

const DIRECTORIO_MIGRACIONES = join(process.cwd(), 'supabase', 'migrations')

/** Migraciones .sql presentes, ignorando lo que no lo sea. */
function migraciones() {
  try {
    return readdirSync(DIRECTORIO_MIGRACIONES).filter((archivo) => archivo.endsWith('.sql'))
  } catch {
    return []
  }
}

const encontradas = migraciones()

if (encontradas.length === 0) {
  console.log(
    'test:rls · sin migraciones todavía: no hay esquema que aislar.\n' +
      '          Este paso se pondrá en rojo solo, en cuanto aparezca la primera migración.',
  )
  exit(0)
}

console.error(
  `\n  test:rls sigue siendo el marcador de posición del encargo 01, y ya hay ${encontradas.length} migración(es):\n`,
)
for (const archivo of encontradas) console.error(`    · ${archivo}`)
console.error(
  '\n  Hay esquema, luego hay datos que pueden filtrarse entre estudiantes.\n' +
    '  Sustituye este script por las pruebas de aislamiento reales antes de seguir:\n' +
    '    · autenticarse como estudiante A e intentar leer notas, matrículas,\n' +
    '      inscripciones y contenido del estudiante B — cero filas en cada consulta;\n' +
    '    · repetir con dos docentes de cursos distintos;\n' +
    '    · fallar si alguna tabla de `public` queda sin RLS habilitada.\n' +
    '\n  Alcance completo en docs/encargos/02-esquema-y-rls.md, punto 6.\n',
)
exit(1)
