-- Encargo 02 · Migración 0001 — Esquema inicial
--
-- Tablas del núcleo académico: identidad, catálogo, cohortes, cursos, contenido y
-- consentimiento. La evaluación llega en 0005 y las plantillas en 0006.
--
-- Referencia: docs/modelo-datos.md (secciones 1-4 y 6) · adr/0002 · adr/0005
--
-- Sobre la RLS: cada tabla se crea con `enable row level security` y SIN políticas.
-- Ese es exactamente el estado de "denegar por defecto" que pide la regla 1 de CLAUDE.md.
-- Las políticas llegan en 0003. Hacerlo así garantiza que ninguna tabla existe, en ningún
-- momento de la secuencia de migraciones, sin RLS activa.

-- ---------------------------------------------------------------------------
-- Utilidad común
-- ---------------------------------------------------------------------------

-- Mantiene `actualizado_en` al día. Sin esto la columna diría siempre la fecha de
-- creación, que es peor que no tenerla: parece información y no lo es.
create or replace function public.tocar_actualizado_en()
returns trigger language plpgsql as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. Identidad y personas
-- ---------------------------------------------------------------------------

create type rol_usuario as enum ('estudiante', 'docente', 'coordinador', 'admin');
create type tipo_doc as enum ('CC', 'TI', 'CE', 'PPT', 'RC');

-- Solo atributos de persona. Ningún campo específico de formación entra aquí: eso mantiene
-- abierta la costura para el módulo de asesoría universitaria (plan.md, sección 1).
create table perfiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  tipo_documento   tipo_doc not null default 'CC',
  numero_documento text not null,
  nombres          text not null,
  apellidos        text not null,
  fecha_nacimiento date,
  telefono         text,
  correo           text,
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now(),
  constraint perfiles_documento_unico unique (tipo_documento, numero_documento)
);

create trigger perfiles_tocar_actualizado_en
  before update on perfiles
  for each row execute function public.tocar_actualizado_en();

-- El rol va en tabla aparte, no como columna: una persona puede ser docente y coordinador
-- a la vez, y eso ocurre en organizaciones pequeñas.
create table usuario_roles (
  usuario_id   uuid not null references perfiles (id) on delete cascade,
  rol          rol_usuario not null,
  otorgado_en  timestamptz not null default now(),
  otorgado_por uuid references perfiles (id),
  primary key (usuario_id, rol)
);

-- ---------------------------------------------------------------------------
-- 2. Catálogo académico
-- ---------------------------------------------------------------------------

create type tipo_programa as enum ('bachillerato', 'tecnico');

create table programas (
  id                      uuid primary key default gen_random_uuid(),
  codigo                  text not null unique,
  nombre                  text not null,
  tipo                    tipo_programa not null,
  escala_min              numeric(2, 1) not null default 1.0,
  escala_max              numeric(2, 1) not null default 5.0,
  -- Sin valor por defecto a propósito (adr/0004): es preferible que falle la carga a que
  -- se siembre una nota mínima inventada. El valor confirmado es 3.0 y se siembra.
  nota_minima_aprobatoria numeric(2, 1) not null,
  decimales_publicados    smallint not null default 1,
  activo                  boolean not null default true,
  creado_en               timestamptz not null default now(),
  check (escala_min < escala_max),
  check (nota_minima_aprobatoria between escala_min and escala_max),
  check (decimales_publicados between 0 and 2)
);

-- La estructura de periodos es dato, no condicionales sobre `tipo` (adr/0005).
create table periodos_programa (
  id             uuid primary key default gen_random_uuid(),
  programa_id    uuid not null references programas (id) on delete cascade,
  orden          smallint not null check (orden >= 1),
  etiqueta       text not null,
  duracion_meses smallint not null check (duracion_meses > 0),
  unique (programa_id, orden)
);

create table materias (
  id                 uuid primary key default gen_random_uuid(),
  programa_id        uuid not null references programas (id),
  periodo_orden      smallint not null,
  codigo             text,
  nombre             text not null,
  orden              smallint not null default 0,
  intensidad_horaria smallint check (intensidad_horaria is null or intensidad_horaria > 0),
  activa             boolean not null default true,
  unique (programa_id, periodo_orden, nombre),
  -- Impide registrar una materia en un periodo que el programa no tiene declarado.
  -- La coherencia la garantiza la base, no la aplicación.
  foreign key (programa_id, periodo_orden) references periodos_programa (programa_id, orden)
);

-- ---------------------------------------------------------------------------
-- 3. Cohortes, matrícula y cursos
-- ---------------------------------------------------------------------------

create type estado_cohorte as enum ('planeada', 'activa', 'finalizada', 'cancelada');
create type estado_matricula as enum ('activa', 'aplazada', 'retirada', 'graduada');
create type estado_curso as enum ('borrador', 'abierto', 'cerrado');
create type estado_inscripcion as enum ('activa', 'retirada', 'aprobada', 'reprobada');

create table cohortes (
  id             uuid primary key default gen_random_uuid(),
  programa_id    uuid not null references programas (id),
  nombre         text not null,
  municipio      text not null,
  departamento   text not null,
  fecha_inicio   date not null,
  -- El periodo activo vive aquí, no en una configuración global.
  periodo_actual smallint not null default 1 check (periodo_actual >= 1),
  estado         estado_cohorte not null default 'planeada',
  creado_en      timestamptz not null default now(),
  unique (programa_id, nombre)
);

-- El vínculo académico maestro. Nunca se borra (regla 6): `estado` + `eliminado_en`.
create table matriculas (
  id              uuid primary key default gen_random_uuid(),
  estudiante_id   uuid not null references perfiles (id),
  cohorte_id      uuid not null references cohortes (id),
  codigo          text unique,
  estado          estado_matricula not null default 'activa',
  fecha_matricula date not null default current_date,
  eliminado_en    timestamptz,
  unique (estudiante_id, cohorte_id),
  -- Soporta la foreign key compuesta de inscripciones (ver más abajo).
  unique (id, estudiante_id)
);

-- La tabla bisagra (adr/0002). Sin ella el modelo no sobrevive al segundo año.
create table cursos (
  id            uuid primary key default gen_random_uuid(),
  cohorte_id    uuid not null references cohortes (id),
  materia_id    uuid not null references materias (id),
  docente_id    uuid references perfiles (id),
  periodo_orden smallint not null check (periodo_orden >= 1),
  -- Gobierna la escritura de notas: al pasar a 'cerrado', las políticas RLS dejan de
  -- permitir escrituras del docente.
  estado        estado_curso not null default 'borrador',
  -- Las materias se dictan en secuencia, no en paralelo (plan.md, decisiones cerradas).
  inicia_el     date,
  termina_el    date,
  abierto_en    timestamptz,
  cerrado_en    timestamptz,
  cerrado_por   uuid references perfiles (id),
  creado_en     timestamptz not null default now(),
  unique (cohorte_id, materia_id),
  check (termina_el is null or inicia_el is null or termina_el >= inicia_el)
);

-- Las notas cuelgan de aquí, nunca de estudiante + materia (adr/0002).
create table inscripciones (
  id            uuid primary key default gen_random_uuid(),
  curso_id      uuid not null references cursos (id),
  matricula_id  uuid not null,
  -- Denormalizado a propósito (adr/0002): las políticas RLS del estudiante se evalúan en
  -- cada consulta del portal, y obligarlas a saltar por matriculas encarece toda lectura.
  -- La foreign key compuesta de abajo garantiza que no pueda desincronizarse.
  estudiante_id uuid not null references perfiles (id),
  -- Permite repetir una materia sin destruir el histórico anterior.
  intento       smallint not null default 1 check (intento >= 1),
  estado        estado_inscripcion not null default 'activa',
  -- Sin redondear (adr/0004). Se redondea una sola vez, al presentarla.
  definitiva    numeric(6, 4),
  creado_en     timestamptz not null default now(),
  unique (curso_id, matricula_id, intento),
  foreign key (matricula_id, estudiante_id) references matriculas (id, estudiante_id)
);

-- ---------------------------------------------------------------------------
-- 4. Contenido
-- ---------------------------------------------------------------------------

create type tipo_recurso as enum ('video_youtube', 'enlace', 'archivo');

create table modulos (
  id           uuid primary key default gen_random_uuid(),
  curso_id     uuid not null references cursos (id) on delete cascade,
  titulo       text not null,
  descripcion  text,
  orden        smallint not null default 0,
  -- El docente arma en borrador y publica cuando está listo.
  publicado    boolean not null default false,
  publicado_en timestamptz
);

create table recursos (
  id           uuid primary key default gen_random_uuid(),
  modulo_id    uuid not null references modulos (id) on delete cascade,
  tipo         tipo_recurso not null,
  titulo       text not null,
  -- Se guarda el identificador, no la URL completa: así el dominio de incrustación
  -- (youtube-nocookie.com, regla 14) es una decisión de una sola línea al renderizar.
  youtube_id   text,
  url          text,
  storage_path text,
  duracion_seg integer check (duracion_seg is null or duracion_seg > 0),
  orden        smallint not null default 0,
  publicado    boolean not null default false,
  check (
    (tipo = 'video_youtube' and youtube_id is not null and url is null and storage_path is null)
    or (tipo = 'enlace' and url is not null and youtube_id is null)
    or (tipo = 'archivo' and storage_path is not null and youtube_id is null)
  )
);

-- Alimenta la barra de avance sin depender de YouTube.
create table progreso_recurso (
  estudiante_id uuid not null references perfiles (id) on delete cascade,
  recurso_id    uuid not null references recursos (id) on delete cascade,
  visto_en      timestamptz not null default now(),
  primary key (estudiante_id, recurso_id)
);

create table anuncios (
  id           uuid primary key default gen_random_uuid(),
  curso_id     uuid references cursos (id) on delete cascade,
  cohorte_id   uuid references cohortes (id) on delete cascade,
  titulo       text not null,
  cuerpo       text not null,
  autor_id     uuid not null references perfiles (id),
  publicado_en timestamptz not null default now(),
  -- Un anuncio es de curso o de cohorte, nunca de ambos ni de ninguno.
  check (num_nonnulls(curso_id, cohorte_id) = 1)
);

-- ---------------------------------------------------------------------------
-- 6. Cumplimiento — Ley 1581
-- ---------------------------------------------------------------------------

create table autorizaciones_datos (
  id                  uuid primary key default gen_random_uuid(),
  titular_id          uuid not null references perfiles (id),
  version_politica    text not null,
  aceptada_en         timestamptz not null default now(),
  es_menor            boolean not null default false,
  acudiente_nombre    text,
  acudiente_documento text,
  -- Traducción a esquema del requisito legal: si el titular es menor, la autorización del
  -- representante legal es obligatoria. Hay menores en Bachillerato Acelerado.
  check (
    not es_menor or (acudiente_nombre is not null and acudiente_documento is not null)
  )
);

-- ---------------------------------------------------------------------------
-- RLS: activada en todas, sin políticas. Denegar por defecto (CLAUDE.md, regla 1).
-- Las políticas llegan en 0003_rls.sql.
-- ---------------------------------------------------------------------------

alter table perfiles enable row level security;
alter table usuario_roles enable row level security;
alter table programas enable row level security;
alter table periodos_programa enable row level security;
alter table materias enable row level security;
alter table cohortes enable row level security;
alter table matriculas enable row level security;
alter table cursos enable row level security;
alter table inscripciones enable row level security;
alter table modulos enable row level security;
alter table recursos enable row level security;
alter table progreso_recurso enable row level security;
alter table anuncios enable row level security;
alter table autorizaciones_datos enable row level security;
