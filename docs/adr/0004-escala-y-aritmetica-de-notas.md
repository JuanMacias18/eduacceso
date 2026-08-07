# ADR 0004 — Escala 1.0–5.0 y aritmética de calificaciones

**Estado:** Aceptada · agosto 2026
**Categoría:** Puerta de una vía. El tipo de dato de las notas no se cambia sin migrar.

## Contexto

Las calificaciones van de **1.0 a 5.0 con un decimal** (3.5, 3.8, 3.9). Sobre esos valores se
calculan promedios ponderados por corte que determinan si un estudiante aprueba una materia,
y que se congelan en un boletín que es un documento oficial.

## Decisión

1. **Tipo de dato: `numeric(2,1)`** para toda nota individual, con
   `CHECK (valor BETWEEN 1.0 AND 5.0)`.
2. **Prohibido `float`, `real` y `double precision`** para calificaciones.
3. **El promedio se calcula con precisión completa y se redondea una sola vez**, al
   presentarlo y al congelarlo en el boletín. La definitiva se almacena sin redondear.
4. El rango, la nota mínima aprobatoria y la política de redondeo son **datos** en la tabla
   `programas`, no constantes en el código.

## Razones

- En coma flotante, `3.85` se almacena como `3.8499999…`. Al mostrarlo con un decimal aparece
  como 3.8 en lugar de 3.9. Es un defecto que no se ve en pruebas con datos inventados y que
  en producción llega como reclamación de un estudiante.
- Redondear cada corte antes de promediar acumula error. Tres notas de 3.45 redondeadas a 3.5
  producen un promedio de 3.5, cuando el real es 3.45. Con un umbral de aprobación de por
  medio, esa diferencia decide si alguien pierde la materia.
- Poner la escala en la tabla `programas` permite que bachillerato y técnicos tengan reglas
  distintas sin bifurcar el código.

## Consecuencias

- Todo cálculo agregado ocurre en Postgres, no en JavaScript. `Number` en JS es coma flotante:
  promediar notas en el cliente reintroduce exactamente el problema que este ADR evita.
- La nota mínima aprobatoria **todavía no está definida** (P1 en `PENDIENTES.md`). La columna
  se crea `NOT NULL` sin valor por defecto: es preferible que falle la carga a que se siembre
  un valor inventado.
