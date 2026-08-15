-- Encargo 02 · Migración 0002 — Índices
--
-- Referencia: docs/modelo-datos.md (sección 8) · CLAUDE.md regla 9.
--
-- Dos grupos:
--
--   1. Cobertura de foreign keys (regla 9). Postgres NO crea estos índices solo. Sin ellos,
--      borrar o actualizar la fila referenciada obliga a un recorrido secuencial de la tabla
--      que apunta. A 200 estudiantes no se nota; a 2.000, sí.
--
--      Se omiten deliberadamente las foreign keys cuya columna ya es la primera de una clave
--      primaria o de un `unique`: ese índice ya sirve, y crear otro igual solo encarece cada
--      escritura. La prueba supabase/tests/0002_indices_fk.test.sql comprueba mecánicamente
--      que ninguna foreign key se quedó sin cobertura, así que esto no depende de que
--      alguien lo revise a ojo.
--
--   2. Caminos calientes del portal, con índices parciales donde la consulta siempre filtra
--      por un estado. El índice parcial es más pequeño y más rápido que el completo.

-- ---------------------------------------------------------------------------
-- 1. Cobertura de foreign keys
-- ---------------------------------------------------------------------------

create index on usuario_roles (otorgado_por);
create index on matriculas (cohorte_id);
create index on cursos (materia_id);
create index on cursos (docente_id);
create index on cursos (cerrado_por);
-- Compuesto, no dos sueltos: la foreign key de inscripciones hacia matriculas es
-- (matricula_id, estudiante_id), y un indice solo sobre matricula_id no la cubre. Como
-- matricula_id es la primera columna, este indice tambien sirve para buscar por ella sola.
create index on inscripciones (matricula_id, estudiante_id);
create index on modulos (curso_id);
create index on recursos (modulo_id);
create index on progreso_recurso (recurso_id);
create index on anuncios (curso_id);
create index on anuncios (cohorte_id);
create index on anuncios (autor_id);
create index on autorizaciones_datos (titular_id);

-- ---------------------------------------------------------------------------
-- 2. Caminos calientes
-- ---------------------------------------------------------------------------

-- El portal del estudiante entra siempre por "mis inscripciones de este curso".
create index on inscripciones (estudiante_id, curso_id);
create index on inscripciones (curso_id) where estado = 'activa';

-- El dashboard resuelve "materias del periodo actual de mi cohorte", y destaca la materia
-- activa por fecha, porque las materias se dictan en secuencia.
create index on cursos (cohorte_id, periodo_orden);
create index on cursos (cohorte_id, inicia_el);

-- La planilla del docente: "mis cursos que puedo calificar ahora mismo".
create index on cursos (docente_id) where estado = 'abierto';

-- Coordinación lista siempre estudiantes activos de una cohorte.
create index on matriculas (cohorte_id) where estado = 'activa';

-- La vista de curso pinta módulos y recursos en orden.
create index on modulos (curso_id, orden);
create index on recursos (modulo_id, orden);

-- Los anuncios se leen por recencia dentro de un curso o una cohorte.
create index on anuncios (curso_id, publicado_en desc);
create index on anuncios (cohorte_id, publicado_en desc);
