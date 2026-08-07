# ADR 0002 — `curso` e `inscripcion` como eje del modelo académico

**Estado:** Aceptada · agosto 2026
**Categoría:** Puerta de una vía. Cambiarla después implica migrar todas las notas.

## Contexto

Hay que decidir de qué cuelgan las notas. La opción intuitiva es asociarlas a
`estudiante` + `materia`.

## Decisión

Se separa **definición** de **instancia**, en tres niveles:

- `materia` — lo que dice el pensum. Catálogo, se define una vez.
- `curso` — esa materia dictada a una **cohorte** concreta, en un **periodo** concreto, con un
  docente. Se crea cada vez que se abre el periodo.
- `inscripcion` — un estudiante dentro de un curso, con número de `intento`.
  **Las notas cuelgan de la inscripción.**

## Alternativas descartadas

| Alternativa | Por qué no |
|---|---|
| Nota sobre `(estudiante, materia)` | Se rompe el primer día en que alguien repite una materia: no hay dónde poner la segunda nota sin destruir la primera |
| Nota sobre `(estudiante, materia, periodo)` | Sobrevive la repetición pero no distingue grupos: no se puede saber qué docente calificó ni comparar cohortes |
| Duplicar materias por cohorte | Multiplica el catálogo por el número de grupos. Con 250 materias y varias cohortes por año, es inmanejable |

## Consecuencias

- Una tabla más al inicio y un `join` adicional en varias consultas.
- A cambio: repetir materia, cambiar de cohorte, homologar y auditar quién calificó son
  operaciones naturales, no cirugía.
- Es el mismo modelo de Canvas LMS (course / section / enrollment), que existe por esta razón.

## Nota de implementación

`inscripciones` lleva `estudiante_id` **denormalizado** además de `matricula_id`, con una
foreign key compuesta contra `matriculas (id, estudiante_id)` que garantiza la consistencia.
Es una decisión de rendimiento: las políticas RLS del estudiante se evalúan en cada consulta,
y obligarlas a saltar por `matriculas` para resolver la pertenencia encarece todas las
lecturas del portal.
