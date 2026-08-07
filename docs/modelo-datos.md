# Modelo de datos

Especificación del esquema inicial. **Esta es la puerta de una vía del proyecto**: cambiarla
después implica migrar datos académicos reales. Léela completa antes de escribir la primera
migración, y no la modifiques sin actualizar el ADR correspondiente.

Referencias: `adr/0002` (curso/inscripción), `adr/0004` (notas), `adr/0005` (periodos).

## Convenciones

- Claves primarias `uuid` con `gen_random_uuid()`.
- `timestamptz` siempre. Nunca `timestamp`.
- Nombres de tabla en plural, columnas en `snake_case`, en español.
- Toda foreign key lleva índice.
- Los registros académicos no se borran: `estado` + `eliminado_en`.

---

## 1. Identidad y personas

```sql
create type rol_usuario as enum ('estudiante','docente','coordinador','admin');
create type tipo_doc     as enum ('CC','TI','CE','PPT','RC');

create table perfiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  tipo_documento    tipo_doc not null default 'CC',
  numero_documento  text not null,
  nombres           text not null,
  apellidos         text not null,
  fecha_nacimiento  date,
  telefono          text,
  correo            text,
  activo            boolean not null default true,
  creado_en         timestamptz not null default now(),
  actualizado_en    timestamptz not null default now(),
  constraint perfiles_documento_unico unique (tipo_documento, numero_documento)
);

create table usuario_roles (
  usuario_id  uuid not null references perfiles(id) on delete cascade,
  rol         rol_usuario not null,
  otorgado_en timestamptz not null default now(),
  otorgado_por uuid references perfiles(id),
  primary key (usuario_id, rol)
);
```

`perfiles` guarda **solo atributos de persona**. Ningún campo específico de formación entra
aquí: eso mantiene abierta la costura para el módulo de asesoría universitaria si algún día se
incorpora (ver plan, sección 1).

El rol va en tabla aparte, no como columna: una persona puede ser docente y coordinador a la
vez, y eso ocurre en organizaciones pequeñas.

---

## 2. Catálogo académico

```sql
create type tipo_programa as enum ('bachillerato','tecnico');

create table programas (
  id                       uuid primary key default gen_random_uuid(),
  codigo                   text not null unique,
  nombre                   text not null,
  tipo                     tipo_programa not null,
  escala_min               numeric(2,1) not null default 1.0,
  escala_max               numeric(2,1) not null default 5.0,
  nota_minima_aprobatoria  numeric(2,1) not null,   -- ⛔ P1: sin default a propósito
  decimales_publicados     smallint not null default 1,
  activo                   boolean not null default true,
  check (escala_min < escala_max),
  check (nota_minima_aprobatoria between escala_min and escala_max)
);

create table periodos_programa (
  id             uuid primary key default gen_random_uuid(),
  programa_id    uuid not null references programas(id) on delete cascade,
  orden          smallint not null check (orden >= 1),
  etiqueta       text not null,          -- 'Cuatrimestre 1' | 'Periodo 1 · Grado 10'
  duracion_meses smallint not null check (duracion_meses > 0),
  unique (programa_id, orden)
);

create table materias (
  id                 uuid primary key default gen_random_uuid(),
  programa_id        uuid not null references programas(id),
  periodo_orden      smallint not null,
  codigo             text,
  nombre             text not null,
  orden              smallint not null default 0,
  intensidad_horaria smallint,
  activa             boolean not null default true,
  unique (programa_id, periodo_orden, nombre),
  foreign key (programa_id, periodo_orden)
    references periodos_programa (programa_id, orden)
);
```

**`nota_minima_aprobatoria` se crea `not null` y sin valor por defecto a propósito.** Es
preferible que la carga de datos falle a que se siembre un valor inventado (ver P1 en
`PENDIENTES.md`).

La foreign key compuesta de `materias` impide registrar una materia en un periodo que el
programa no tiene declarado. La base garantiza la coherencia; no se delega a la aplicación.

Datos de arranque esperados: técnicos → 3 filas de 4 meses; Bachillerato Acelerado → 2 filas
de 6 meses.

---

## 3. Cohortes, matrícula y cursos

```sql
create type estado_cohorte    as enum ('planeada','activa','finalizada','cancelada');
create type estado_matricula  as enum ('activa','aplazada','retirada','graduada');
create type estado_curso      as enum ('borrador','abierto','cerrado');
create type estado_inscripcion as enum ('activa','retirada','aprobada','reprobada');

create table cohortes (
  id             uuid primary key default gen_random_uuid(),
  programa_id    uuid not null references programas(id),
  nombre         text not null,          -- 'Puerto López 2026-1'
  municipio      text not null,
  departamento   text not null,
  fecha_inicio   date not null,
  periodo_actual smallint not null default 1,
  estado         estado_cohorte not null default 'planeada',
  unique (programa_id, nombre)
);

create table matriculas (
  id              uuid primary key default gen_random_uuid(),
  estudiante_id   uuid not null references perfiles(id),
  cohorte_id      uuid not null references cohortes(id),
  codigo          text unique,
  estado          estado_matricula not null default 'activa',
  fecha_matricula date not null default current_date,
  eliminado_en    timestamptz,
  unique (estudiante_id, cohorte_id),
  unique (id, estudiante_id)          -- soporta la FK compuesta de inscripciones
);

create table cursos (
  id            uuid primary key default gen_random_uuid(),
  cohorte_id    uuid not null references cohortes(id),
  materia_id    uuid not null references materias(id),
  docente_id    uuid references perfiles(id),
  periodo_orden smallint not null,
  estado        estado_curso not null default 'borrador',
  inicia_el     date,          -- las materias se dictan en secuencia, no en paralelo
  termina_el    date,
  abierto_en    timestamptz,
  cerrado_en    timestamptz,
  cerrado_por   uuid references perfiles(id),
  unique (cohorte_id, materia_id)
);

create table inscripciones (
  id            uuid primary key default gen_random_uuid(),
  curso_id      uuid not null references cursos(id),
  matricula_id  uuid not null,
  estudiante_id uuid not null references perfiles(id),
  intento       smallint not null default 1,
  estado        estado_inscripcion not null default 'activa',
  definitiva    numeric(6,4),           -- sin redondear (ver adr/0004)
  unique (curso_id, matricula_id, intento),
  foreign key (matricula_id, estudiante_id)
    references matriculas (id, estudiante_id)
);
```

`inscripciones.estudiante_id` está **denormalizado a propósito**: las políticas RLS del
estudiante se evalúan en cada consulta del portal, y obligarlas a saltar por `matriculas` para
resolver pertenencia encarece todas las lecturas. La foreign key compuesta garantiza que no
pueda desincronizarse.

`cursos.estado` gobierna la escritura de notas: cuando pasa a `cerrado`, las políticas RLS
dejan de permitir escrituras del docente.

---

## 4. Contenido

```sql
create type tipo_recurso as enum ('video_youtube','enlace','archivo');

create table modulos (
  id           uuid primary key default gen_random_uuid(),
  curso_id     uuid not null references cursos(id) on delete cascade,
  titulo       text not null,
  descripcion  text,
  orden        smallint not null default 0,
  publicado    boolean not null default false,
  publicado_en timestamptz
);

create table recursos (
  id           uuid primary key default gen_random_uuid(),
  modulo_id    uuid not null references modulos(id) on delete cascade,
  tipo         tipo_recurso not null,
  titulo       text not null,
  youtube_id   text,
  url          text,
  storage_path text,
  duracion_seg integer,
  orden        smallint not null default 0,
  publicado    boolean not null default false,
  check (
    (tipo = 'video_youtube' and youtube_id is not null and url is null and storage_path is null) or
    (tipo = 'enlace'        and url is not null        and youtube_id is null) or
    (tipo = 'archivo'       and storage_path is not null and youtube_id is null)
  )
);

create table progreso_recurso (
  estudiante_id uuid not null references perfiles(id) on delete cascade,
  recurso_id    uuid not null references recursos(id) on delete cascade,
  visto_en      timestamptz not null default now(),
  primary key (estudiante_id, recurso_id)
);

create table anuncios (
  id           uuid primary key default gen_random_uuid(),
  curso_id     uuid references cursos(id) on delete cascade,
  cohorte_id   uuid references cohortes(id) on delete cascade,
  titulo       text not null,
  cuerpo       text not null,
  autor_id     uuid not null references perfiles(id),
  publicado_en timestamptz not null default now(),
  check (num_nonnulls(curso_id, cohorte_id) = 1)
);
```

Se guarda `youtube_id`, no la URL completa: la URL se construye al renderizar y así el
dominio de incrustación (`youtube-nocookie.com`) es una decisión de una sola línea.

---

## 5. Evaluación

Esta sección se derivó de la **Guía de Asignatura** real y del **calendario de entregas**.
La ponderación tiene **dos niveles**, no uno. Ver `adr/0006`.

Ejemplo real (Materiales y Metalurgia Básica, Técnico en Soldador y Oxicortador):

| Componente | Corte | Peso del curso | Ítems internos |
|---|---|---|---|
| Unidad 1 | 1 | 30% | Actividad 70% · Quiz 30% |
| Unidad 2 | 2 | 30% | Actividad 70% · Quiz 30% |
| Unidad 3 | 3 | 25% | Actividad 100% |
| Examen Final Integrador | 3 | 15% | Examen 100% |

Los cortes 30/30/40 salen de aquí: el tercero es Unidad 3 (25) + Examen Final (15).

```sql
create type tipo_componente as enum ('unidad','examen_final','otro');
create type tipo_item       as enum ('actividad','taller','quiz','examen','otro');

create table componentes_evaluacion (
  id        uuid primary key default gen_random_uuid(),
  curso_id  uuid not null references cursos(id) on delete cascade,
  corte     smallint not null check (corte >= 1),
  nombre    text not null,                    -- 'Unidad 1', 'Examen Final Integrador'
  tipo      tipo_componente not null,
  peso      numeric(5,2) not null check (peso > 0 and peso <= 100),  -- % del curso
  inicia_el date,
  termina_el date,
  orden     smallint not null default 0,
  unique (curso_id, nombre)
);

create table items_calificables (
  id               uuid primary key default gen_random_uuid(),
  componente_id    uuid not null references componentes_evaluacion(id) on delete cascade,
  nombre           text not null,             -- 'Taller práctico', 'Quiz 1'
  tipo             tipo_item not null,
  peso             numeric(5,2) not null check (peso > 0 and peso <= 100), -- % del componente
  disponible_desde timestamptz,               -- 'se habilita'
  fecha_limite     timestamptz,               -- 'se entrega'
  recurso_url      text,                      -- enlace externo al taller o quiz (v1)
  orden            smallint not null default 0
);

create table notas (
  id             uuid primary key default gen_random_uuid(),
  item_id        uuid not null references items_calificables(id) on delete cascade,
  inscripcion_id uuid not null references inscripciones(id),
  valor          numeric(2,1) not null check (valor between 1.0 and 5.0),
  observacion    text,
  publicada      boolean not null default false,
  publicada_en   timestamptz,
  registrada_por uuid not null references perfiles(id),
  registrada_en  timestamptz not null default now(),
  actualizada_en timestamptz,
  unique (item_id, inscripcion_id)
);
```

### Plantillas de evaluación

La estructura es la misma para todas las materias, y coordinación debe poder cambiarla sin
tocar código. Al abrir un curso, la plantilla se **copia**; el curso queda independiente
(ver `adr/0007`).

```sql
create table plantillas_evaluacion (
  id                uuid primary key default gen_random_uuid(),
  programa_id       uuid references programas(id),   -- null = aplica a todos
  nombre            text not null,
  es_predeterminada boolean not null default false,
  activa            boolean not null default true
);

create table plantilla_componentes (
  id           uuid primary key default gen_random_uuid(),
  plantilla_id uuid not null references plantillas_evaluacion(id) on delete cascade,
  corte        smallint not null,
  nombre       text not null,
  tipo         tipo_componente not null,
  peso         numeric(5,2) not null check (peso > 0 and peso <= 100),
  orden        smallint not null default 0
);

create table plantilla_items (
  id                      uuid primary key default gen_random_uuid(),
  plantilla_componente_id uuid not null references plantilla_componentes(id) on delete cascade,
  nombre                  text not null,
  tipo                    tipo_item not null,
  peso                    numeric(5,2) not null check (peso > 0 and peso <= 100),
  orden                   smallint not null default 0
);

alter table cursos
  add column plantilla_id            uuid references plantillas_evaluacion(id),
  add column estructura_personalizada boolean not null default false;
```

Una función `aplicar_plantilla(p_curso uuid, p_plantilla uuid)` inserta los componentes e ítems
del curso en una sola operación. Se ejecuta al pasar el curso de `borrador` a `abierto`.

`estructura_personalizada` se marca en `true` cuando alguien edita la estructura de un curso
concreto, para que coordinación vea cuáles se apartaron del estándar.

**Quién edita qué:** coordinación y administración modifican plantillas y estructuras de curso.
El docente **solo captura notas**: si cada docente pudiera cambiar los pesos, dos cursos de la
misma materia dejarían de ser comparables.

Plantilla predeterminada, tomada de la guía de asignatura real:

| Componente | Corte | Peso | Ítems |
|---|---|---|---|
| Unidad 1 | 1 | 30 | Actividad 70 · Quiz 30 |
| Unidad 2 | 2 | 30 | Actividad 70 · Quiz 30 |
| Unidad 3 | 3 | 25 | Actividad 100 |
| Examen Final Integrador | 3 | 15 | Examen 100 |

**Validaciones al abrir el curso** (no como constraint por fila: durante la configuración el
docente pasa por estados intermedios donde no suman):

- Σ `componentes_evaluacion.peso` por curso = 100.
- Σ `items_calificables.peso` por componente = 100.

**`publicada` no es opcional.** Sin ese flag el estudiante ve notas a medio digitar.

### Cálculo de la definitiva

```
nota_componente = Σ (item.valor × item.peso) / 100
definitiva      = Σ (nota_componente × componente.peso) / 100
```

Se calcula en Postgres con precisión completa y se redondea **una sola vez** al presentarla
(ver `adr/0004`). `inscripciones.definitiva` es `numeric(6,4)` y guarda el valor sin redondear.

### Habilitaciones

Reglas confirmadas:

- Se habilita solo si la definitiva queda **entre 2.0 y 2.9**.
- La recuperación se aplica **sobre la nota definitiva del curso**, no solo sobre el examen
  final. (Sobre el examen final —15% del curso— el mecanismo sería inoperante: no alcanzaría
  para sacar a nadie de la banda 2.0–2.9.)
- Tope de **3.0**, y el sistema **conserva siempre la calificación más alta**: presentar la
  recuperación nunca puede dejar al estudiante peor de como estaba.
- Se registra aparte, para trazabilidad.

```sql
create type estado_habilitacion as enum ('autorizada','presentada','anulada');

create table habilitaciones (
  id                  uuid primary key default gen_random_uuid(),
  inscripcion_id      uuid not null references inscripciones(id),
  definitiva_original numeric(6,4) not null,
  nota_habilitacion   numeric(2,1) check (nota_habilitacion between 1.0 and 5.0),
  tope_aplicado       numeric(2,1) not null,
  nota_final          numeric(2,1),          -- greatest(original, least(recuperacion, tope))
  estado              estado_habilitacion not null default 'autorizada',
  autorizada_por      uuid not null references perfiles(id),
  autorizada_en       timestamptz not null default now(),
  registrada_por      uuid references perfiles(id),
  registrada_en       timestamptz,
  observacion         text,
  unique (inscripcion_id)
);
```

**`inscripciones.definitiva` nunca se sobrescribe.** La nota resultante vive en
`habilitaciones.nota_final` y una vista calcula la nota efectiva:

```sql
create or replace view v_nota_efectiva as
select i.id as inscripcion_id,
       i.definitiva                                as nota_periodo,
       h.nota_habilitacion,
       coalesce(h.nota_final, round(i.definitiva, 1)) as nota_efectiva,
       -- nota_final se calcula como:
       --   greatest( round(i.definitiva,1), least(h.nota_habilitacion, h.tope_aplicado) )
       (h.id is not null)                          as hubo_habilitacion
from inscripciones i
left join habilitaciones h
  on h.inscripcion_id = i.id and h.estado = 'presentada';
```

Es exactamente la trazabilidad pedida: nota original, nota de habilitación y nota final
resultante conviven, y ninguna borra a la otra.

Los rangos y el tope son **configuración por programa**, no constantes:

```sql
alter table programas
  add column habilitacion_min   numeric(2,1) not null default 2.0,
  add column habilitacion_max   numeric(2,1) not null default 2.9,
  add column habilitacion_tope  numeric(2,1) not null default 3.0;
```

### Boletines

```sql
create table boletines (
  id            uuid primary key default gen_random_uuid(),
  matricula_id  uuid not null references matriculas(id),
  periodo_orden smallint not null,
  promedio      numeric(6,4) not null,
  pdf_path      text,
  generado_en   timestamptz not null default now(),
  generado_por  uuid not null references perfiles(id),
  unique (matricula_id, periodo_orden)
);
```

Un boletín congela el resultado. No es una consulta que se recalcula: es un documento emitido
en una fecha, y debe seguir diciendo lo mismo dentro de dos años.

---

## 6. Cumplimiento y auditoría

```sql
create table autorizaciones_datos (
  id                    uuid primary key default gen_random_uuid(),
  titular_id            uuid not null references perfiles(id),
  version_politica      text not null,
  aceptada_en           timestamptz not null default now(),
  es_menor              boolean not null default false,
  acudiente_nombre      text,
  acudiente_documento   text,
  check (not es_menor or (acudiente_nombre is not null and acudiente_documento is not null))
);

create table auditoria (
  id          bigserial primary key,
  tabla       text not null,
  registro_id uuid not null,
  accion      text not null check (accion in ('INSERT','UPDATE','DELETE')),
  actor_id    uuid,
  antes       jsonb,
  despues     jsonb,
  ocurrido_en timestamptz not null default now()
);
create index on auditoria (tabla, registro_id, ocurrido_en desc);
```

`auditoria` se alimenta por trigger sobre `notas`, `inscripciones`, `matriculas` y `cursos`.
Es la diferencia entre un sistema académico y una hoja de cálculo compartida: cuando un
estudiante reclame una nota, tiene que existir el registro de quién la puso, cuándo y qué
valor tenía antes.

El `check` de menores es la traducción a esquema del requisito de Ley 1581: si el titular es
menor de edad, la autorización del representante legal es obligatoria.

---

## 7. Seguridad — RLS

### Funciones auxiliares

Van en un esquema `app` propio, `security definer` y con `search_path` fijo. Consultar una
tabla con RLS directamente desde una política produce recursión, y se manifiesta como un
timeout sin mensaje claro.

```sql
create schema if not exists app;

create or replace function app.tiene_rol(p_rol rol_usuario)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from usuario_roles
    where usuario_id = auth.uid() and rol = p_rol
  );
$$;

create or replace function app.es_docente_del_curso(p_curso uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from cursos
    where id = p_curso and docente_id = auth.uid()
  );
$$;

create or replace function app.curso_de_item(p_item uuid)
returns uuid language sql stable security definer set search_path = public, pg_temp as $$
  select c.curso_id
  from items_calificables i
  join componentes_evaluacion c on c.id = i.componente_id
  where i.id = p_item;
$$;

create or replace function app.curso_abierto(p_curso uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from cursos where id = p_curso and estado = 'abierto');
$$;
```

### Patrón de políticas

RLS se habilita en **todas** las tablas, y la ausencia de política significa denegar.

```sql
alter table notas enable row level security;

-- El estudiante ve únicamente sus notas publicadas
create policy notas_lectura_estudiante on notas for select using (
  publicada = true
  and exists (
    select 1 from inscripciones i
    where i.id = notas.inscripcion_id and i.estudiante_id = auth.uid()
  )
);

-- El docente ve y escribe las de sus cursos, solo mientras estén abiertos
create policy notas_lectura_docente on notas for select using (
  app.es_docente_del_curso(
    (select c.curso_id from items_calificables i
       join componentes_evaluacion c on c.id = i.componente_id
      where i.id = notas.item_id))
);

create policy notas_escritura_docente on notas for all using (
  app.curso_de_item(notas.item_id) is not null
  and app.es_docente_del_curso(app.curso_de_item(notas.item_id))
  and app.curso_abierto(app.curso_de_item(notas.item_id))
) with check (
  app.es_docente_del_curso(app.curso_de_item(notas.item_id))
  and app.curso_abierto(app.curso_de_item(notas.item_id))
);

-- Coordinación y administración pueden corregir aun con el curso cerrado (queda auditado)
create policy notas_coordinacion on notas for all
  using (app.tiene_rol('coordinador') or app.tiene_rol('admin'))
  with check (app.tiene_rol('coordinador') or app.tiene_rol('admin'));
```

**`with check` es obligatorio en toda política de escritura.** `using` controla qué filas se
pueden tocar; sin `with check`, un docente podría reasignar una nota a una inscripción de otro
curso.

### Matriz de acceso

| Rol | Lee | Escribe |
|---|---|---|
| Estudiante | Sus matrículas, sus inscripciones, sus notas **publicadas**, contenido **publicado** de sus cursos | Su progreso de recursos y datos de contacto de su perfil |
| Docente | Sus cursos y los estudiantes inscritos en ellos | Contenido y notas de sus cursos, **solo con el curso abierto** |
| Coordinador | Su ámbito completo | Matrículas, cursos, apertura y cierre de periodos, corrección de notas |
| Admin | Todo | Todo, auditado |

---

## 8. Índices

Además del índice implícito de cada clave primaria y de cada `unique`:

```sql
create index on inscripciones (estudiante_id, curso_id);
create index on inscripciones (curso_id) where estado = 'activa';
create index on notas (inscripcion_id);
create index on notas (item_id);
create index on componentes_evaluacion (curso_id, corte);
create index on items_calificables (componente_id, orden);
create index on habilitaciones (inscripcion_id);
create index on plantilla_componentes (plantilla_id, orden);
create index on cursos (plantilla_id) where estructura_personalizada;
create index on cursos (cohorte_id, periodo_orden);
create index on cursos (cohorte_id, inicia_el);
create index on cursos (docente_id) where estado = 'abierto';
create index on matriculas (cohorte_id) where estado = 'activa';
create index on modulos (curso_id, orden);
create index on recursos (modulo_id, orden);
create index on progreso_recurso (estudiante_id);
```

Los índices parciales (`where`) son deliberados: las consultas del portal casi siempre filtran
por estado activo o abierto, y el índice parcial es más pequeño y más rápido que el completo.

---

## 9. La consulta caliente

El dashboard del estudiante se resuelve en **una función RPC**, no en varias consultas desde
el cliente. Con 300 ms de latencia móvil, doce peticiones son cuatro segundos de espera.

```sql
create or replace function dashboard_estudiante()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  -- devuelve: matrícula activa, programa, periodo actual, cursos del periodo con
  -- avance de recursos, últimas notas publicadas y anuncios recientes
$$;
```

Se mide con `explain analyze` sobre datos sembrados a escala realista (200 estudiantes ×
6 materias × 3 cortes), no con la tabla vacía.
