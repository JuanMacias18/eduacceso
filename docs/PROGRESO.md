# Progreso

> El agente lee este archivo al iniciar cada sesión y lo actualiza al cerrar cada tarea.
> Formato: estado, fecha, y lo que la siguiente sesión necesita saber.
>
> Para lo que falta hasta producción y lo que hay que auditar antes de que entre un dato
> real, ver [`RUTA-A-PRODUCCION.md`](RUTA-A-PRODUCCION.md). Lo que hay que pedirle al cliente
> está en [`peticion-a-coordinacion.md`](peticion-a-coordinacion.md).

## Estado general

| Encargo | Estado | Fecha | Notas |
|---|---|---|---|
| 01 · Cimientos | **cerrado** | 2026-08-15 | Todos los criterios cumplidos. Repo público, `main` protegida con el check `verify`, secret scanning y Dependabot activos |
| 02 · Esquema y RLS | en revisión | 2026-08-19 | 9 de 9 rebanadas. 8 migraciones, 83 pruebas pgTAP. Pendiente el Bucle 2: revisión humana |
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

La regla de dirección de dependencias está **demostrada en la historia de git**, como pide el
criterio de aceptación: el commit `54f84bd` introduce un `import '@/evaluacion'` dentro de
`academico`, `npm run verify` se detiene en rojo en el paso de `lint`, y `55dcfdf` lo revierte.
Los dos commits se dejaron a propósito para que la evidencia quede en el repositorio.

**Hallazgo durante el trabajo.** La detección automática de contenido de Tailwind v4 rastreaba
todo el repositorio y generaba reglas para nombres de clase que solo existen como texto en los
mensajes de ayuda de `scripts/verificar-tailwind-v4.mjs`: `bg-sky-500` y `text-ellipsis`
viajaban al CSS de producción sin que ningún componente las usara. Acotado con
`source('../src')`; el CSS bajó de 7.81 kB a 5.60 kB.

**Compuertas humanas — estado al cerrar la sesión.**

1. ✅ **Push de `dev` y CI en verde.** Autorizado y hecho. El workflow `verify` pasa en
   GitHub Actions en ~30 s. El job se llama `verify` a secas: ese nombre es el identificador
   que usará la protección de rama, así que se dejó corto y estable a propósito.
2. ✅ **`main` protegida.** Requiere PR (0 aprobaciones, para que un equipo de una persona
   pueda mezclar), exige el check `verify` en verde y con la rama al día, historia lineal, y
   prohíbe force-push y borrado.

   **El repositorio se hizo público el 2026-08-14 para conseguirlo**, por decisión de
   dirección: tanto la protección clásica como los rulesets son de pago en repositorios
   privados de cuenta personal. Antes de publicar se barrió la historia completa de los 14
   commits: **cero credenciales**, `.env.local` nunca versionado, y ningún dato personal de
   estudiantes (todavía no hay semilla).

   **Dos cosas que conviene tener presentes ahora que es público:**

   - `docs/PENDIENTES.md` P1 dice por escrito que se está evaluando **cobrar por la
     recuperación** y que falta visto bueno jurídico, con menores de por medio. Es material
     interno y hoy es legible por cualquiera. Conviene decidir si se reformula o se saca del
     repositorio.
   - Pagar GitHub Pro más adelante **no vuelve privado lo ya publicado**, y tampoco es lo que
     protege los datos de los menores: eso lo hará la RLS del encargo 02. Si el objetivo es
     volver a privado, hay que hacerlo pronto y asumiendo que lo indexado no se recupera.
3. ✅ **`supabase start` verificado.** Postgres **17.6** respondiendo, esquema `auth` con 23
   tablas, GoTrue `/health` en 200, REST en 200 y Studio en 54423. `npm run db:tipos` se
   ejecutó contra la base real y regeneró `tipos-supabase.ts`. Comprobado además el camino
   completo desde el navegador: el módulo del cliente se importa, `obtenerCliente()`
   construye, apunta a `54421` y `auth.getSession()` responde sin error.

   Hicieron falta dos ajustes para que arrancara, ambos en `supabase/config.toml`:

   - **Puertos movidos al bloque `544xx`** (API 54421, base 54422, Studio 54423). El bloque
     por defecto `543xx` estaba ocupado por otro proyecto Supabase local (`business-os`).
     El CLI sugería parar ese proyecto; se prefirió reasignar puertos, que no interrumpe
     trabajo ajeno y deja los dos proyectos conviviendo.
   - **`[analytics] enabled = false`.** En Windows, analytics (Logflare) exige el demonio de
     Docker expuesto en `tcp://localhost:2375`; sin eso queda *unhealthy* y arrastra a
     `storage` y `pg_meta`, con lo que `supabase start` falla entero. Es el explorador de
     logs de Studio y no lo necesita nada de este proyecto.

   **La guardia de `service_role` quedó demostrada contra credenciales reales:** se le pasaron
   al cliente, desde el navegador, la `SERVICE_ROLE_KEY` y la `sb_secret_…` que imprimió este
   mismo `supabase start`, y las rechazó las dos.

**Decisiones que requieren confirmación humana.**

- ~~**Versión de Postgres.**~~ **Resuelto el 2026-08-07: Postgres 17.** Es el valor por
  defecto del CLI y lo que recibe un proyecto Supabase nuevo, así que local y producción
  coinciden. La tabla de stack de `CLAUDE.md` se actualizó de 15 a 17.
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

### 2026-08-15 · Encargo 02 — En curso (3 de 9 rebanadas)

**Hecho.**

- **`0001_esquema_inicial.sql`** — tipos y las 14 tablas del núcleo académico: identidad,
  catálogo, cohortes, matrículas, cursos, inscripciones, contenido y consentimiento de Ley
  1581. Falta evaluación (0005) y plantillas (0006).
- **`0002_indices.sql`** — cobertura de foreign keys y caminos calientes de la sección 8.
- **Arnés pgTAP** por `supabase test db`, sustituyendo al marcador del encargo 01.

**Decisión de secuencia que conviene conocer.** El encargo separa el esquema (`0001`) de la
RLS (`0003`), pero la regla 1 pide RLS en toda tabla nueva con política por defecto de
denegar. Se concilian **activando RLS en la misma migración que crea cada tabla**, sin
políticas —que es exactamente el estado de denegar por defecto—, y dejando las políticas para
`0003`. Así ninguna tabla existe, en ningún punto de la secuencia, sin RLS. Las tablas de
`0005` y `0006` seguirán el mismo patrón.

**El trinquete de `test:rls` funcionó.** En cuanto apareció la primera migración se puso en
rojo y obligó a escribir el runner de verdad antes de poder commitear. Era exactamente para
eso.

**Dos pruebas de aptitud, ambas comparando contra cadena vacía en vez de contra un conteo,
para que el fallo diga *qué* se rompió:**

1. *Ninguna tabla sin RLS.* Demostrada: al crear una tabla descuidada, el fallo imprime
   `have: tabla_descuidada`.
2. *Ninguna foreign key sin índice.* **Encontró un defecto real el primer día:** la foreign
   key compuesta `(matricula_id, estudiante_id)` de `inscripciones` no estaba cubierta —
   había dos índices sueltos, uno por columna, y ninguno la cubre. No se habría visto
   revisando el archivo a ojo.

**`0003_rls.sql` — funciones `app` y políticas.** 46 políticas sobre las 14 tablas, ninguna
de escritura sin `with check`. Las de aislamiento están demostradas por mutación: al
desactivar la RLS de `matriculas`, la prueba se pone en rojo.

**Hallazgo grave durante esta rebanada: faltaban los `GRANT` de tabla.** La RLS solo entra a
decidir si el rol ya tiene el privilegio; sin `grant select`, toda consulta muere con
`permission denied for table` y las políticas **ni se evalúan**. Los privilegios por defecto
del proyecto no cubrían las tablas nuevas.

De haber llegado así a producción, la aplicación no habría funcionado en absoluto — y el
síntoma empuja exactamente hacia el atajo que prohíbe la regla 2: sacar la `service_role` key
para "arreglarlo". Ahora los privilegios son **explícitos** en la migración, no heredados de
comportamiento implícito que puede diferir entre local y producción.

Con ellos entra una segunda barrera por debajo de la RLS: **`delete` no se concede** salvo en
`modulos`, `recursos` y `progreso_recurso`. Aunque mañana alguien escriba una política
`for all` de más sobre `matriculas` o `inscripciones`, el borrado sigue sin pasar (regla 6).
`anon` no recibe ningún privilegio: aquí no hay nada público.

**Alcance del coordinador — RESUELTO el 2026-08-15: organizacional completo.** La matriz de
la sección 7 dice "su ámbito completo" y `plan.md` dice "su cohorte / sede completa", pero el
modelo de datos no tiene con qué acotarlo: no existe `cohortes.coordinador_id` ni tabla
puente. Confirmado con dirección que **EduAcceso es un solo instituto**, así que un
coordinador ve todas las cohortes y una tabla puente sería complejidad sin contrapartida.

No es una puerta de una vía: acotarlo después es añadir una tabla y endurecer políticas, sin
migrar un solo dato.

> **Revisar si** aparece una segunda sede con coordinación propia, o si se contrata
> coordinación por región. Ese es el momento de introducir el alcance, no antes.

**`0005` evaluación, `0006` plantillas, `0007` corrección y la semilla.** 69 pruebas pgTAP en
ocho archivos. Lo verificado por mutación: aplanar los pesos devuelve 3.5 en vez de 1.05 y
una definitiva de 20.0 sobre una escala que llega a 5.0; desactivar la RLS de `matriculas`
pone en rojo la prueba de aislamiento; quitar el disparador de auditoría tumba 6 de 9.

**`0007` corrige a `0006` con una migración nueva, no editándola.** `0006` ya estaba
commiteada y en `origin`, así que aplica la condición de parada 3. El defecto:
`curso_10_aplicar_plantilla` estaba en `before insert or update`, y en un INSERT el
disparador corre antes de que exista la fila del curso — copiar la plantilla violaba la clave
foránea con un error que no explicaba nada. Ahora solo dispara en UPDATE, que además es el
flujo real: los cursos nacen en borrador y coordinación los abre.

**Dos defectos propios que destapó la semilla, ambos en mis pruebas:**

1. Una prueba esperaba que un `UPDATE` bloqueado por RLS lanzara error. **No lanza: afecta
   cero filas.** Solo el `with check` lanza 42501. Habría pasado por el motivo equivocado si
   el `using` hubiera estado mal escrito. Ahora se comprueban las dos mecánicas por separado,
   y conviene recordarlo al revisar cualquier prueba de RLS.
2. Un `insert ... select ... from items_calificables` sin acotar. Funcionaba con la base
   vacía y se rompió en cuanto existió `seed.sql`, porque recogía también los ítems
   sembrados. **Una prueba que asume la base vacía es una prueba con fecha de caducidad.**

**Sobre la semilla.** Datos íntegramente ficticios (regla 19): 2 programas, 5 periodos, 10
materias, 1 cohorte, 8 estudiantes, 2 docentes, 1 coordinador, 5 cursos secuenciales con el
primero abierto, contenido con identificadores de YouTube marcadores y las notas de la Unidad
1 publicadas. Dos estudiantes son menores y llevan su autorización de acudiente, como exige
la Ley 1581.

Las notas sembradas son **deterministas, no aleatorias**: una semilla que cambia en cada
reset hace imposible razonar sobre lo que se ve en pantalla. La contraseña de todas las
cuentas es `eduacceso-local`, credencial de desarrollo para una base que se recrea con
`db reset`.

**Rebanada 9 — cierre de la suite.** Al repasar la lista del encargo punto por punto
aparecieron **dos huecos reales**, los dos del mismo tipo: algo escrito en una rebanada
temprana que nunca se completó cuando llegaron las tablas de después.

1. **La prueba de aislamiento nunca probó `notas`.** Se escribió en la rebanada de RLS, antes
   de que `notas` existiera (0005), y la palabra solo aparecía en un comentario. Era el
   **primer punto** de la lista del encargo y el dato más sensible del sistema.
   `0009_aislamiento_notas.test.sql` lo cubre con el caso difícil: los dos estudiantes en el
   **mismo curso**, para que la política tenga que discriminar por inscripción y no le baste
   con filtrar por curso.

2. **`v_nota_efectiva` no tenía `GRANT`.** Correcta y a la vez inservible: cualquier consulta
   moría con `permission denied for view`. La invariante que introduje en la rebanada 5 solo
   miraba `relkind = 'r'`, es decir tablas, y la vista se coló por ahí. Corregido en
   `0008_grant_vista_nota_efectiva.sql` —migración nueva, no edición de `0005`— y la
   invariante ahora cubre vistas.

**Dos invariantes nuevas sobre vistas**, porque una vista es la forma más discreta de abrir
un agujero:

- toda vista concede `SELECT` a `authenticated`;
- **toda vista se ejecuta con `security_invoker`**. Verificado por mutación: al quitárselo a
  `v_nota_efectiva`, un estudiante pasa de ver 1 fila a ver **10** — el historial de notas de
  todo el instituto. Lo atrapan dos pruebas a la vez, la estructural y la de comportamiento.

**Notas técnicas para la siguiente sesión.**

- Al convertir `pg_index.indkey` a `smallint[]`, el array **empieza en 0**, no en 1.
- `supabase db reset` termina con "Restarting containers…" y Postgres tarda un momento más en
  aceptar conexiones. Lanzar pruebas inmediatamente después da un falso rojo con el esquema
  aparentemente vacío. Si aparece un fallo raro justo tras un reset, es esto.
- El CI levanta **solo Postgres** (`supabase start -x …`): las pruebas pgTAP hablan directo
  con la base. CI pasó de ~30 s a ~2 min.

**Pendiente.** Rebanadas 4 a 9: políticas RLS y funciones `app`, auditoría, evaluación de dos
niveles con habilitaciones, plantillas, semilla anonimizada y el resto de la suite de pruebas
del encargo.

### 2026-08-14 · Encargo 01 — Revisión propia y correcciones

Segunda pasada sobre el código del encargo antes de dar paso al 02. Aparecieron **dos
defectos propios**, los dos corregidos:

1. **`detectSessionInUrl: false` en el cliente de Supabase.** Lo justifiqué citando
   `adr/0003`, y ese ADR dice justo lo contrario: docentes, coordinación y administración
   tienen **recuperación estándar**, y los estudiantes que registran correo tienen
   **recuperación automática**. Los dos flujos aterrizan con los tokens en la URL, así que
   con la opción en `false` la sesión no se habría establecido y la recuperación de
   contraseña habría fallado **en silencio**. No habría dado la cara hasta el encargo 03.
   Corregido a `true`.

2. **`leerEntorno` fallaba hacia el lado permisivo.** Un token con forma de JWT cuyo payload
   no se puede decodificar se trataba como clave válida: la comprobación de `service_role`
   no llegaba a mirar nada y nadie se enteraba. Ahora se rechaza con un mensaje que apunta a
   la causa habitual (clave copiada a medias). De paso, el payload se decodifica pasando por
   `TextDecoder` en vez de leer los bytes de `atob` como si fueran texto.

Dos mejoras menores: `.npmrc` con `engine-strict=true`, para que instalar con una versión de
Node fuera de rango falle en el momento y no más tarde con errores raros; y
`verificar-presupuesto.mjs` recorre el manifiesto por claves en vez de buscar la clave de
vuelta por identidad, que era una vuelta innecesaria.

**Verificado:** `verify` en verde, 12 pruebas. Comprobado además en el navegador que el
cliente construye, que un JWT ilegible se rechaza y que la `service_role` real sigue
rechazándose.

**Nota honesta sobre la cobertura:** la prueba del payload con acentos fija el
comportamiento correcto, pero no habría detectado el defecto anterior — el texto mal
decodificado seguía siendo JSON válido y el campo `role` se leía igual. La prueba que sí
cambia el comportamiento es la del token ilegible.

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
