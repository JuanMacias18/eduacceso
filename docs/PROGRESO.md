# Progreso

> El agente lee este archivo al iniciar cada sesión y lo actualiza al cerrar cada tarea.
> Formato: estado, fecha, y lo que la siguiente sesión necesita saber.

## Estado general

| Encargo | Estado | Fecha | Notas |
|---|---|---|---|
| 01 · Cimientos | en revisión | 2026-08-07 | Código completo y `verify` verde. Faltan 3 compuertas humanas (ver abajo) |
| 02 · Esquema y RLS | pendiente | — | Desbloqueado: reglas de evaluación y recuperación cerradas |
| 03 · Esqueleto vertical | pendiente | — | |

## Bitácora

<!-- Entrada más reciente arriba. Formato:

### AAAA-MM-DD · Encargo NN
**Hecho:** …
**Verificado:** `npm run verify` verde / rojo en …
**Pendiente:** …
**Decisiones que requieren confirmación humana:** …
**Archivos tocados:** …
-->

### 2026-08-07 · Encargo 01 — Cimientos

**Hecho.** Repositorio listo para desarrollar, sin código de producto. Rama `dev` creada;
todo el trabajo va ahí. Siete commits, uno por rebanada.

- **Esqueleto:** Vite 8.2 + React 18.3.1 + TypeScript 6.0 estricto + Tailwind v4.3.3.
  React 18 va fijado a mano porque la plantilla oficial de Vite ya scaffoldea React 19.
- **Estructura** `academico` / `contenido` / `evaluacion` / `shared`, más `scripts/`.
- **ESLint 10 + Prettier**, con `--max-warnings 0` para que `verify` sea binario de verdad.
- **`npm run verify`** encadenado literal como en `AGENT_LOOP.md`, verde de punta a punta.
- **Supabase local** inicializado, cliente tipado perezoso y `.env.example` sin secretos.
- **CI** en GitHub Actions ejecutando `npm run verify`, el mismo comando que corre en local.

**Tres reglas escritas convertidas en comprobaciones que fallan el build:**

1. *Dirección de dependencias* (plan 10.2). `academico` no puede importar de `contenido` ni
   de `evaluacion`. Cubre alias (`@/evaluacion`), ruta relativa (`../evaluacion`) y también
   los `import type`.
2. *Coherencia de Tailwind* (`scripts/verificar-tailwind-v4.mjs`). Falla si aparecen patrones
   de v3 sobre la instalación de v4. Ver `adr/0008`.
3. *Clave de servicio en el cliente* (regla 3 de `CLAUDE.md`). `leerEntorno` rechaza el
   arranque si `VITE_SUPABASE_ANON_KEY` contiene una `service_role`, en los dos formatos que
   emite Supabase. Comprobado por mutación: al desactivar la guardia, las pruebas se ponen
   en rojo.

**`test:rls` es un marcador de posición, pero con trinquete.** Sale verde mientras
`supabase/migrations/` esté vacío y **se pone en rojo solo** en cuanto aparezca la primera
migración, explicando que hay que sustituirlo por las pruebas de aislamiento del encargo 02.
Se autodestruye justo cuando empieza ese encargo. Probado en los dos estados.

**Verificado.** `npm run verify` en verde. 10 pruebas unitarias. Bundle inicial 44.3 KB gzip,
24.6% del presupuesto de 180 KB. `npm run dev` levanta sin un solo error de consola.

**Hallazgo durante el trabajo.** La detección automática de contenido de Tailwind v4 rastreaba
todo el repositorio y generaba reglas para nombres de clase que solo existen como texto en los
mensajes de ayuda de `scripts/verificar-tailwind-v4.mjs`: `bg-sky-500` y `text-ellipsis`
viajaban al CSS de producción sin que ningún componente las usara. Acotado con
`source('../src')`; el CSS bajó de 7.81 kB a 5.60 kB.

**Pendiente — tres compuertas humanas.**

1. **`supabase start` sin verificar.** Docker Desktop no estaba corriendo durante la sesión.
   `supabase init` sí quedó hecho. Es criterio de aceptación del encargo.
2. **Push de `dev` a `origin` y CI en verde.** No se hizo: es una acción hacia afuera y
   requiere autorización.
3. **Proteger `main`.** Es un cambio de configuración del repositorio en GitHub.

**Decisiones que requieren confirmación humana.**

- **Versión de Postgres.** `supabase init` generó `major_version = 17` en
  `supabase/config.toml`; la tabla de stack de `CLAUDE.md` dice **Postgres 15**. Hay que
  cerrarlo **antes de la primera migración**: es la versión con la que se desarrolla y
  debería coincidir con la del proyecto Supabase real.
- **Tailwind v4 en vez de v3.** Documentado en `adr/0008` con las razones y las versiones
  comprobadas. Si se prefiere la v3, es el momento de decirlo.
- **`docs/` excluida de Prettier.** El formateo automático reflowea las tablas y los
  diagramas de `plan.md` y `modelo-datos.md`. Se revirtió y se excluyó.

**Archivos tocados.** `package.json`, `package-lock.json`, `vite.config.ts`, `tsconfig*.json`,
`eslint.config.js`, `.prettierrc.json`, `.prettierignore`, `.gitattributes`, `.gitignore`,
`.env.example`, `index.html`, `README.md`, `public/favicon.svg`, `src/` (App, main, index.css,
los cuatro módulos, `shared/config/entorno.ts` + pruebas, `shared/datos/supabase.ts` +
tipos), `scripts/` (tres comprobaciones), `.github/workflows/verify.yml`, `supabase/`
(config.toml), `docs/adr/0008-tailwind-v4.md`, este archivo.

## Deuda técnica aceptada conscientemente

<!-- Cosas que se dejaron a medias a propósito, con la razón y cuándo se retoman. -->

- **Playwright y `npm run test:e2e` no existen todavía.** `CLAUDE.md` los lista en su tabla de
  comandos, pero no están en el alcance del encargo 01 ni entran en `verify`. Se montan en el
  encargo 03, que es quien tiene pantallas que probar. *Retomar: encargo 03.*
- **Lighthouse CI y el presupuesto de LCP tampoco.** `test:budget` hoy mide solo el tamaño del
  bundle inicial, que sí se puede medir sin producto. El LCP < 2.5 s en 3G necesita un
  dashboard que cargar. *Retomar: encargo 03, es criterio de aceptación suyo.*
- **`contenido` ↔ `evaluacion` no está restringido.** La regla documentada solo prohíbe que
  `academico` dependa de los otros dos. No he inventado una regla adicional; si se quiere que
  esos dos módulos tampoco se importen entre sí, es una línea en `eslint.config.js`.
  *Retomar: cuando alguno de los dos módulos tenga contenido real.*
- **`auth.enable_signup = true` en `supabase/config.toml`.** Es el valor por defecto del CLI y
  solo afecta a la base local. Con identidad asignada por coordinación (`adr/0003`) debería
  quedar en `false`. No lo he tocado porque la configuración de autenticación es alcance del
  encargo 03. *Retomar: encargo 03.*
