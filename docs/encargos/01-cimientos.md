# Encargo 01 — Cimientos del repositorio

**Objetivo:** dejar el proyecto listo para desarrollar. **No se escribe código de producto.**

## Alcance

1. Inicializar el proyecto: Vite + React + TypeScript + Tailwind.
2. Estructura de carpetas según `CLAUDE.md` (`src/academico`, `src/contenido`,
   `src/evaluacion`, `src/shared`).
3. Configurar Supabase local (`supabase init`) y el cliente tipado.
4. ESLint + Prettier + `tsconfig` en modo estricto.
5. GitHub Actions con: `lint`, `typecheck`, `test`, y el chequeo de dirección de dependencias
   (`contenido` y `evaluacion` pueden importar de `academico`; lo contrario falla el build).
6. Ramas `dev` y `main`, con `main` protegida.
7. `.env.example` con las variables necesarias y **ningún secreto real** en el repo.
8. **Script `npm run verify`** encadenando `lint`, `typecheck`, `test`, `test:rls` y
   `test:budget`. Al inicio varios estarán casi vacíos: da igual, el comando tiene que existir
   y salir en verde desde el primer día (ver `docs/AGENT_LOOP.md`).
9. `docs/PROGRESO.md` inicializado.
10. README corto: cómo levantar el proyecto en local.

## Fuera de alcance

Tablas, migraciones, pantallas, autenticación. Eso es el encargo 02.

## Criterio de aceptación

- `npm run dev` levanta la app en blanco sin errores de consola.
- `supabase start` levanta Postgres y Auth locales.
- `npm run verify` sale en verde y es el mismo comando que corre el CI.
- Un push a `dev` ejecuta el CI completo en verde.
- Un import de `academico` hacia `evaluacion` hace fallar el build. Demuéstralo con un commit
  de prueba y revierte.
