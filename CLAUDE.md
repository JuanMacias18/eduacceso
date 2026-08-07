# EduAcceso — Plataforma académica

Portal académico para EduAcceso S.A.S. (Colombia). Los estudiantes consultan sus materias,
clases en video, material y notas; los docentes cargan las notas de sus propios cursos.

Antes de escribir código lee `docs/modelo-datos.md`. Antes de asumir cualquier valor de
negocio lee `docs/PENDIENTES.md`. El protocolo de trabajo iterativo está en
`docs/AGENT_LOOP.md`, y el estado del proyecto en `docs/PROGRESO.md`: **léelos al iniciar
cada sesión**.

## Stack

| Capa | Tecnología |
|---|---|
| Front | React 18 + Vite + TypeScript + Tailwind |
| Datos / Auth / Storage | Supabase (Postgres 17) |
| Backend | Supabase Edge Functions (Deno) |
| Hosting | Vercel |
| Pruebas | Vitest + Playwright + pgTAP |

## Comandos

```bash
npm run dev                      # app en local
supabase start                   # Postgres + Auth locales
supabase migration new <nombre>  # crear migración
supabase db reset                # recrear BD local desde migraciones + seed
npm run test                     # unitarias
npm run test:rls                 # aislamiento entre usuarios (obligatorio)
npm run test:e2e                 # Playwright
npm run lint && npm run typecheck
npm run verify                   # todo lo anterior + RLS + presupuesto. Debe estar verde
                                 # antes de cada commit (ver docs/AGENT_LOOP.md)
```

## Glosario del dominio

Estos términos NO son intercambiables. Confundirlos rompe el modelo:

- **programa** — la oferta académica: "Técnico Laboral en Electricidad Industrial",
  "Bachillerato Acelerado". Es catálogo.
- **materia** — una asignatura definida en el pensum de un programa, con su periodo.
  Es catálogo: se define una vez y no cambia por grupo.
- **cohorte** — un grupo real que cursa un programa: "Puerto López 2026-1".
- **curso** — una materia dictada a una cohorte en un periodo, con un docente.
  Es la **instancia**. Se crea cada vez que se abre el periodo.
- **matrícula** — vínculo de un estudiante con una cohorte. Es el registro maestro.
- **inscripción** — un estudiante dentro de un curso. **Las notas cuelgan de aquí**,
  nunca de `estudiante` + `materia`.
- **corte** — agrupación de componentes para reportar y publicar notas (30% / 30% / 40%).
- **componente de evaluación** — una unidad del curso o el examen final, con peso **sobre el
  curso** (Unidad 1 = 30%, Examen Final = 15%).
- **ítem calificable** — lo que se califica dentro de un componente, con peso **sobre el
  componente** (Actividad = 70% de su unidad, no del curso).
- **habilitación** — recuperación de una materia con definitiva entre 2.0 y 2.9. Nunca
  sobrescribe la nota original.

## Reglas no negociables

Romper cualquiera de estas es un defecto, no una decisión de estilo.

### Seguridad
1. **RLS habilitada en TODA tabla nueva**, con política por defecto de denegar.
   Hay un test en CI que falla si aparece una tabla sin RLS.
2. **Nunca deshabilites RLS ni uses la `service_role` key para resolver un error de
   permisos.** Si una consulta devuelve cero filas y crees que debería devolver datos,
   la política está mal escrita: arréglala. Este es el atajo que deja el sistema abierto.
3. La `service_role` key vive solo en Edge Functions. Jamás en el cliente ni en un `.env`
   que llegue al bundle.
4. Las políticas que consultan otras tablas usan funciones `SECURITY DEFINER` con
   `search_path` fijo. Consultar directamente una tabla con RLS desde una política produce
   recursión, y se manifiesta como un timeout sin mensaje claro.

### Datos
5. **Las notas son `numeric(2,1)`. Nunca `float`, `real` ni `double precision.`**
6. **Nada se borra.** Los registros académicos usan `estado` y `eliminado_en`. Un `DELETE`
   sobre notas, matrículas o inscripciones es un incidente.
7. **Todo cambio de esquema es un archivo de migración versionado** en `supabase/migrations/`.
   Nunca SQL suelto contra la base, nunca cambios desde el panel de Supabase.
8. `timestamptz` siempre, nunca `timestamp`. Zona de referencia: `America/Bogota`.
9. Índice en cada foreign key. Sin excepciones.
10. Los promedios y agregados se calculan en Postgres (vistas o funciones), no en React.
11. **Los pesos son de dos niveles.** El peso de un ítem es relativo a su componente, no al
    curso. Una Actividad de 70% dentro de una Unidad de 30% pesa 21% de la definitiva.
    Nunca aplanes los pesos al guardarlos (ver `adr/0006`).
12. La nota aprobatoria es **3.0** y vive en `programas.nota_minima_aprobatoria`, no en el
    código.

### Rendimiento
13. El dashboard del estudiante se resuelve en **una sola llamada RPC**. Si necesitas tres
    consultas para pintar una pantalla, la consulta está mal diseñada.
14. **Los videos de YouTube se cargan con fachada**: miniatura estática, y el `iframe` se
    monta solo al hacer clic. Un `iframe` de YouTube pesa cerca de 1 MB y los estudiantes
    están en 3G rural. Dominio de incrustación: `youtube-nocookie.com`.
15. Presupuesto: bundle inicial < 180 KB gzip, LCP < 2.5 s en 3G simulada. Verificado en CI.
16. Toda lista pagina. Nunca `select *` sin límite.

### Proceso
17. Rama `dev` para desarrollo, `main` a producción. Nunca commits directos a `main`.
18. Ningún PR entra con `test:rls` en rojo.
19. Los datos de prueba son anonimizados. Nunca copies producción a un entorno de pruebas
    con nombres y documentos reales.

## Cuando falte información

**Si necesitas un valor de negocio que no está en `docs/`, DETENTE y pregunta.**
No inventes una nota mínima aprobatoria, ni una cantidad de cortes, ni pesos de evaluación,
ni reglas de habilitación. Un valor inventado que llega a una migración se convierte en
datos incorrectos que hay que migrar después. `docs/PENDIENTES.md` tiene la lista de lo que
todavía no está definido.

## Estructura

```
src/
  academico/    catálogo, cohortes, matrícula, cursos
  contenido/    módulos, recursos, anuncios
  evaluacion/   ítems, notas, boletines
  shared/       ui, hooks, cliente de datos
supabase/
  migrations/   SQL versionado
  functions/    Edge Functions
docs/
  plan.md, modelo-datos.md, PENDIENTES.md, adr/, encargos/
```

`contenido` y `evaluacion` pueden importar de `academico`. **Lo contrario rompe el build**
(hay una verificación en CI).
