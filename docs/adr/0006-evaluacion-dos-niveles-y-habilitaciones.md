# ADR 0006 — Ponderación de dos niveles y habilitaciones

**Estado:** Aceptada · agosto 2026
**Categoría:** Puerta de una vía. Cambiarla implica migrar notas ya cargadas.
**Origen:** Guía de Asignatura real y calendario de entregas de EduAcceso.

## Contexto

La primera versión del esquema asumía una lista plana de ítems calificables, cada uno con un
peso sobre el total del curso. La guía de asignatura real muestra que la ponderación tiene
**dos niveles**:

- El curso se divide en **unidades** con peso propio (30%, 30%, 25%) más un **examen final
  integrador** (15%).
- Dentro de cada unidad hay ítems con peso relativo **a la unidad**: Actividad 70%, Quiz 30%.

Un peso de 70% no significa 70% del curso: significa 70% de una unidad que a su vez vale 30%.
El peso efectivo de esa actividad sobre la nota final es 21%.

Los cortes 30/30/40 que reporta coordinación son consistentes con esto: el tercer corte es
Unidad 3 (25%) más Examen Final (15%).

## Decisión

Se introduce `componentes_evaluacion` entre `cursos` e `items_calificables`:

```
curso → componente (peso % del curso) → ítem (peso % del componente) → nota
```

`corte` queda como atributo del componente, no como tabla propia: es una agrupación para
reportar y publicar, no un nivel de cálculo.

## Alternativa descartada

**Aplanar los pesos al cargar** (guardar 21% en vez de 30% × 70%). Se descartó porque:

- El docente configuraría números que no coinciden con la guía impresa que tiene en la mano.
  Todo error de digitación se vuelve invisible.
- El estudiante no podría ver su nota por unidad, que es como está organizado el curso y como
  espera verlo.
- Cambiar el peso de una unidad obligaría a recalcular todos sus ítems a mano.

## Consecuencias

- Dos validaciones al abrir el curso: los componentes suman 100 en el curso, y los ítems
  suman 100 dentro de cada componente.
- Un `join` más para llegar del ítem al curso. Se resuelve con la función
  `app.curso_de_item()`, que además evita repetir subconsultas en las políticas RLS.
- El cálculo de la definitiva ocurre en dos pasos, ambos en Postgres.

## Habilitaciones

Reglas confirmadas por coordinación:

| Regla | Valor |
|---|---|
| Nota mínima aprobatoria | 3.0 |
| Rango que da derecho a habilitar | definitiva entre 2.0 y 2.9 |
| Tope de la nota de recuperación | 3.0 |
| Regla de resultado | **Se conserva la calificación más alta**: `greatest(definitiva_original, least(nota_recuperacion, 3.0))` |
| Momento | Después de cerrado el periodo |
| Registro | Nota original + nota de habilitación + nota final resultante, las tres visibles |

`inscripciones.definitiva` **nunca se sobrescribe**. La habilitación vive en su propia tabla y
una vista (`v_nota_efectiva`) resuelve cuál es la nota vigente. Esto es lo que hace posible
responder a una reclamación dos años después.

Los rangos y el tope son columnas de `programas`, no constantes: bachillerato y técnicos
podrían diferir, y el reglamento cambia con más frecuencia que el código.

**Por qué "la más alta" y no reemplazo literal:** un reemplazo puro deja peor al estudiante que
intenta recuperar y saca menos que su definitiva original. Eso desincentiva presentarse y
produce reclamaciones. Con `greatest`, presentar la recuperación es siempre neutro o positivo.

## Base de aplicación de la recuperación — CONFIRMADO

La recuperación se aplica **sobre la definitiva completa del curso**, no sobre el componente de
examen final.

Se evaluó la alternativa y se descartó por aritmética: el examen final vale 15% del curso, así
que un estudiante con definitiva 2.5 y examen 2.0 que sacara 5.0 en la recuperación llegaría a
2.95 — seguiría reprobado. Sobre el examen final, el mecanismo no habría podido rescatar a
casi nadie de la banda 2.0–2.9.

## Pendiente asociado

Ver `PENDIENTES.md`: si se implementa el mecanismo de recuperación para definitivas entre
1.0 y 1.9.
