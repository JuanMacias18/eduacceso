# ADR 0007 — Plantilla de evaluación copiada al curso

**Estado:** Aceptada · agosto 2026
**Relacionado:** `adr/0006` (ponderación de dos niveles)

## Contexto

La estructura de evaluación es **la misma para las ~250 materias**: tres unidades (30/30/25)
con Actividad 70% + Quiz 30% dentro de cada una, más un Examen Final Integrador del 15%.
Coordinación quiere poder **modificarla cuando se requiera**, sin que eso implique tocar código.

Configurar esa estructura a mano en cada uno de los cursos que se abren cada cuatrimestre es
inviable: son cientos de cursos por año, cada uno con cuatro componentes y seis ítems.

## Decisión

Existe una **plantilla de evaluación** con sus componentes e ítems. Al abrir un curso, la
plantilla se **copia** a las tablas del curso.

```
plantilla_evaluacion → plantilla_componentes → plantilla_items
                              │ (copia al abrir el curso)
                              ▼
curso → componentes_evaluacion → items_calificables
```

Tras la copia, el curso es **independiente**: quien tenga permiso puede ajustar pesos, añadir
o quitar ítems en ese curso concreto, sin afectar a nadie más.

## Por qué copiar y no referenciar

Esta es la parte importante. Si el curso apuntara a la plantilla en vivo, **cambiar la
plantilla en marzo alteraría retroactivamente la ponderación de un curso calificado y cerrado
en enero**. Las notas ya publicadas cambiarían de valor sin que nadie tocara una nota.

En un sistema académico eso es inaceptable: un curso cerrado tiene que seguir diciendo lo
mismo dentro de dos años. La copia cuesta unas filas más por curso y elimina la clase entera
de ese problema.

Es el mismo principio que ya aplica a `boletines`: los documentos y las reglas con las que se
calificó se congelan, no se recalculan.

## Quién puede modificar la estructura

- **Coordinación y administración:** editan la plantilla y también la estructura de un curso
  concreto.
- **Docente:** captura notas, **no modifica pesos ni componentes.** Si cualquier docente
  pudiera cambiar la ponderación, "estructura obligatoria" dejaría de significar algo y dos
  cursos de la misma materia no serían comparables.

`cursos.estructura_personalizada` se marca en `true` cuando un curso se aparta de la plantilla,
para que coordinación pueda ver de un vistazo cuáles se desviaron del estándar.

## Consecuencias

- Abrir un cuatrimestre completo genera cientos de filas de una sola operación. Es una
  inserción masiva, no un ciclo fila por fila.
- Cambiar la plantilla afecta solo a los cursos que se abran **después**. Los ya abiertos
  siguen con la estructura con la que empezaron, que es lo correcto.
- Se puede tener más de una plantilla (por ejemplo, una para técnicos y otra para
  bachillerato) sin tocar código.
