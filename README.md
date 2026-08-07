# EduAcceso

Portal académico de EduAcceso S.A.S. Los estudiantes consultan sus materias, clases en video,
material y notas; los docentes cargan las notas de sus propios cursos.

Antes de tocar código: [`CLAUDE.md`](CLAUDE.md) tiene las reglas no negociables,
[`docs/modelo-datos.md`](docs/modelo-datos.md) el esquema y
[`docs/PROGRESO.md`](docs/PROGRESO.md) el estado actual.

## Requisitos

| Herramienta | Versión | Para qué |
|---|---|---|
| Node | ≥ 22.12 (o 20.19+) | la aplicación |
| Docker Desktop | corriendo | `supabase start` levanta Postgres y Auth en contenedores |
| Supabase CLI | ≥ 2.x | base de datos local y migraciones |

## Arranque

```bash
npm install
cp .env.example .env.local
supabase start                   # imprime la URL y la clave anon locales
```

Copia de la salida de `supabase start` los dos valores a `.env.local`:

```
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_ANON_KEY=<la clave "anon key" que imprimió el comando>
```

Y arranca:

```bash
npm run dev
```

> La aplicación **rechaza arrancar** si en `VITE_SUPABASE_ANON_KEY` hay una clave con
> privilegios de servicio. Esa clave ignora las políticas RLS y solo puede vivir en las Edge
> Functions (`CLAUDE.md`, regla 3).

Si perdiste los valores, `supabase status` los vuelve a imprimir.

## Comandos

```bash
npm run dev          # aplicación en local
npm run verify       # la puerta: debe estar verde antes de cada commit
npm run test:watch   # pruebas en modo continuo mientras desarrollas
npm run format       # aplica Prettier (la documentación queda excluida a propósito)
npm run db:tipos     # regenera los tipos de TypeScript desde la base local
```

### Qué hay dentro de `verify`

Es el mismo comando que corre el CI. Si pasa en tu máquina y falla allí, el problema es el
entorno, no el criterio.

| Paso | Qué protege |
|---|---|
| `lint` | Prettier, ESLint, la dirección de dependencias entre módulos y la coherencia de Tailwind v4 |
| `typecheck` | TypeScript en modo estricto |
| `test` | Lógica de dominio |
| `test:rls` | Aislamiento entre usuarios. **No negociable** (ver `docs/plan.md` 5.3) |
| `test:budget` | Bundle inicial < 180 KB gzip |

En el encargo 01, `test:rls` es todavía un marcador de posición: sale en verde mientras no
haya migraciones, y se pone en rojo solo en cuanto aparezca la primera. Las pruebas de
aislamiento reales son el encargo 02.

## Base de datos

```bash
supabase migration new <nombre>   # crear una migración
supabase db reset                 # recrear la base local desde migraciones + semilla
npm run db:tipos                  # regenerar los tipos después de un cambio de esquema
```

Todo cambio de esquema es un archivo versionado en `supabase/migrations/`. Nunca SQL suelto
contra la base, nunca cambios desde el panel de Supabase.

## Estructura

```
src/
  academico/    catálogo, cohortes, matrícula, cursos
  contenido/    módulos, recursos, anuncios
  evaluacion/   ítems, notas, boletines
  shared/       ui, hooks, cliente de datos, configuración
scripts/        comprobaciones que corren dentro de verify
supabase/       migraciones y configuración local
docs/           plan, modelo de datos, ADR y encargos
```

`contenido` y `evaluacion` pueden importar de `academico`. **Lo contrario rompe el lint**, con
un mensaje que dice por qué.

## Ramas

`dev` para desarrollo, `main` a producción. Nunca commits directos a `main`.
