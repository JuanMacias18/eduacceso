# ADR 0005 — Estructura de periodos como dato, no como código

**Estado:** Aceptada · agosto 2026

## Contexto

Los dos tipos de programa tienen estructuras temporales distintas:

- **Técnicos laborales:** 3 cuatrimestres (~4 meses cada uno).
- **Bachillerato Acelerado:** 2 periodos de 6 meses (dos años de bachillerato en uno).

Y no hay garantía de que no aparezca un tercer formato más adelante.

## Decisión

La estructura de periodos vive en una tabla `periodos_programa`, con una fila por periodo:
orden, etiqueta y duración en meses. **No se codifica con condicionales sobre
`programas.tipo`.**

`materias` referencia el periodo mediante foreign key compuesta contra
`periodos_programa (programa_id, orden)`, de modo que la base impide registrar una materia en
un periodo que ese programa no tiene.

## Alternativa descartada

Un `if (programa.tipo === 'bachillerato')` repartido por la aplicación. Funciona hoy y se
convierte en deuda el día que aparezca un programa con otra estructura: hay que encontrar cada
condicional, y siempre queda uno.

## Consecuencias

- Añadir un programa con otra estructura es insertar filas, no desplegar código.
- El literal `3` no aparece en ninguna parte de la aplicación.
- Costo: una tabla más y una consulta adicional al construir el catálogo. Se cachea sin
  problema porque cambia casi nunca.

## Pendiente relacionado

Cuántos **cortes de calificación** hay dentro de cada periodo sigue sin definirse
(P2 en `PENDIENTES.md`). Los cortes son un nivel distinto al periodo y se modelan en
`items_calificables.corte`.
