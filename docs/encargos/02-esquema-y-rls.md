# Encargo 02 — Esquema, RLS y pruebas de aislamiento

**Objetivo:** el modelo de datos completo, con seguridad verificada. **Sin interfaz.**

Este es el encargo más delicado del proyecto: es la puerta de una vía. Lee
`docs/modelo-datos.md` completo y los ADR `0002`, `0004`, `0006` y `0007` antes de empezar.

## Alcance

1. Migración `0001_esquema_inicial.sql` con todas las tablas, tipos, constraints y foreign
   keys de `docs/modelo-datos.md`. Una sola migración, ordenada por dependencias.
2. Migración `0002_indices.sql` con los índices de la sección 8.
3. Migración `0003_rls.sql`: `enable row level security` en **todas** las tablas, funciones
   auxiliares del esquema `app` y políticas según la matriz de acceso de la sección 7.
4. Migración `0004_auditoria.sql`: trigger de auditoría sobre `notas`, `inscripciones`,
   `matriculas` y `cursos`.
5. Migración `0005_evaluacion.sql`: `componentes_evaluacion`, `items_calificables`,
   `habilitaciones`, la vista `v_nota_efectiva` y la función de cálculo de definitiva en dos
   niveles (componente → curso).
   `habilitaciones.nota_final = greatest(round(definitiva,1), least(nota_recuperacion, tope))`,
   aplicado **sobre la definitiva completa**.
6. Migración `0006_plantillas.sql`: `plantillas_evaluacion`, `plantilla_componentes`,
   `plantilla_items`, las columnas nuevas de `cursos` y la función `aplicar_plantilla()`.
   Sembrar la plantilla predeterminada con la estructura de la guía real.
7. Semilla (`supabase/seed.sql`) con datos **ficticios**: 2 programas (1 técnico + bachillerato),
   sus periodos, ~10 materias, 1 cohorte, 8 estudiantes, 2 docentes, 1 coordinador. Un curso
   sembrado con la estructura real de la guía: Unidad 1 (30%, Actividad 70 + Quiz 30),
   Unidad 2 (30%, igual), Unidad 3 (25%, Actividad 100), Examen Final (15%).
6. Pruebas:
   - `test:rls` — **la prueba que no es negociable.** Autenticarse como estudiante A e
     intentar leer notas, matrículas, inscripciones y contenido del estudiante B. Toda
     consulta debe devolver cero filas. Repetir con dos docentes de cursos distintos.
   - Prueba de que **ninguna tabla queda sin RLS**: consultar `pg_class` / `pg_policies` y
     fallar si aparece una tabla del esquema `public` sin RLS habilitada.
   - Prueba de que un docente **no puede escribir notas con el curso cerrado**.
   - Prueba de que un `numeric(2,1)` rechaza `5.5` y `0.9`.
   - **Prueba del cálculo de dos niveles:** con la estructura de la guía sembrada, una
     Actividad de 5.0 en la Unidad 1 debe aportar exactamente 21% de la definitiva
     (30% × 70%), no 70%.
   - Prueba de que una habilitación con nota 4.5 produce `nota_final = 3.0` por el tope, y
     que `inscripciones.definitiva` **no cambió**.
   - Prueba de que abrir un curso falla si los componentes no suman 100, o si los ítems de
     un componente no suman 100.
   - **Prueba de independencia de la plantilla:** aplicar la plantilla a un curso, editar el
     peso de un componente **de ese curso**, y verificar que la plantilla y los demás cursos
     no cambiaron.
   - Prueba de que un docente **no puede** modificar componentes ni pesos, solo notas.
8. Todas las pruebas corriendo en CI, bloqueando el merge.

## Restricciones

- `programas.nota_minima_aprobatoria` = **3.0** (confirmado). Sigue siendo `not null` sin
  default en el esquema: el valor se siembra, no se asume.
- La recuperación para definitivas entre 1.0 y 1.9 (P1 en `PENDIENTES.md`) **no está
  decidida**: no la implementes. El rango 2.0–2.9 sí está cerrado.
- La plantilla se **copia** al curso, nunca se referencia en vivo (ver `adr/0007`).
- Nada de `float` para notas.
- Ninguna política sin `with check` en operaciones de escritura.

## Criterio de aceptación

`supabase db reset` recrea la base desde cero, siembra los datos y `npm run test:rls` pasa en
verde. El test de "tabla sin RLS" falla si se añade una tabla nueva sin política —
demuéstralo y revierte.
