-- Encargo 02 · Migración 0005 — Evaluación de dos niveles y habilitaciones
--
-- Referencia: docs/modelo-datos.md (sección 5) · adr/0004 (aritmética) · adr/0006 (dos niveles)
--
-- La ponderación tiene DOS niveles, y esa es la razón de que exista `componentes_evaluacion`
-- entre el curso y los ítems:
--
--     curso → componente (peso % del CURSO) → ítem (peso % del COMPONENTE) → nota
--
-- Un peso de 70% no significa 70% del curso: significa 70% de una unidad que a su vez vale
-- 30%. El peso efectivo de esa actividad sobre la definitiva es 21%. Nunca se aplanan los
-- pesos al guardarlos (regla 11).

create type tipo_componente as enum ('unidad', 'examen_final', 'otro');
create type tipo_item as enum ('actividad', 'taller', 'quiz', 'examen', 'otro');
create type estado_habilitacion as enum ('autorizada', 'presentada', 'anulada');

-- ---------------------------------------------------------------------------
-- Estructura de evaluación del curso
-- ---------------------------------------------------------------------------

create table componentes_evaluacion (
  id         uuid primary key default gen_random_uuid(),
  curso_id   uuid not null references cursos (id) on delete cascade,
  -- El corte es una agrupación para reportar y publicar, no un nivel de cálculo (adr/0006).
  corte      smallint not null check (corte >= 1),
  nombre     text not null,
  tipo       tipo_componente not null,
  peso       numeric(5, 2) not null check (peso > 0 and peso <= 100), -- % del curso
  inicia_el  date,
  termina_el date,
  orden      smallint not null default 0,
  unique (curso_id, nombre)
);

create table items_calificables (
  id               uuid primary key default gen_random_uuid(),
  componente_id    uuid not null references componentes_evaluacion (id) on delete cascade,
  nombre           text not null,
  tipo             tipo_item not null,
  peso             numeric(5, 2) not null check (peso > 0 and peso <= 100), -- % del COMPONENTE
  disponible_desde timestamptz,
  fecha_limite     timestamptz,
  -- En v1 los talleres y quizzes se publican como enlace externo y el docente registra la
  -- nota. No hay módulo de entregas.
  recurso_url      text,
  orden            smallint not null default 0,
  unique (componente_id, nombre)
);

-- `numeric(2,1)`, jamás float (adr/0004): en coma flotante un 3.85 se guarda como 3.8499…
-- y aparece redondeado hacia abajo en el boletín. Es un defecto invisible en pruebas y una
-- reclamación real en producción.
create table notas (
  id             uuid primary key default gen_random_uuid(),
  item_id        uuid not null references items_calificables (id) on delete cascade,
  inscripcion_id uuid not null references inscripciones (id),
  valor          numeric(2, 1) not null check (valor between 1.0 and 5.0),
  observacion    text,
  -- Sin esto el estudiante ve notas a medio digitar. No es opcional.
  publicada      boolean not null default false,
  publicada_en   timestamptz,
  registrada_por uuid not null references perfiles (id),
  registrada_en  timestamptz not null default now(),
  actualizada_en timestamptz,
  unique (item_id, inscripcion_id)
);

-- ---------------------------------------------------------------------------
-- Habilitaciones
--
-- Rangos y tope son configuración por programa, no constantes: bachillerato y técnicos
-- podrían diferir, y el reglamento cambia con más frecuencia que el código.
--
-- El rango 1.0–1.9 (P1 en PENDIENTES.md) NO está decidido y NO se implementa.
-- ---------------------------------------------------------------------------

alter table programas
  add column habilitacion_min  numeric(2, 1) not null default 2.0,
  add column habilitacion_max  numeric(2, 1) not null default 2.9,
  add column habilitacion_tope numeric(2, 1) not null default 3.0,
  add constraint programas_habilitacion_rango check (habilitacion_min <= habilitacion_max);

create table habilitaciones (
  id                  uuid primary key default gen_random_uuid(),
  inscripcion_id      uuid not null references inscripciones (id),
  definitiva_original numeric(6, 4) not null,
  nota_habilitacion   numeric(2, 1) check (nota_habilitacion between 1.0 and 5.0),
  tope_aplicado       numeric(2, 1) not null,
  -- greatest(round(definitiva,1), least(nota_habilitacion, tope)). Se calcula por
  -- disparador para que la regla viva en un solo sitio.
  nota_final          numeric(2, 1) check (nota_final between 1.0 and 5.0),
  estado              estado_habilitacion not null default 'autorizada',
  autorizada_por      uuid not null references perfiles (id),
  autorizada_en       timestamptz not null default now(),
  registrada_por      uuid references perfiles (id),
  registrada_en       timestamptz,
  observacion         text,
  unique (inscripcion_id)
);

-- ---------------------------------------------------------------------------
-- Cálculo de la definitiva — en dos pasos, ambos en Postgres (regla 10)
-- ---------------------------------------------------------------------------

-- Devuelve la definitiva SIN redondear. Se redondea una sola vez, al presentarla (adr/0004):
-- redondear cada corte antes de promediar acumula error, y con un umbral de aprobación de
-- por medio esa diferencia decide si alguien pierde la materia.
--
-- Los ítems sin nota no cuentan todavía: durante el periodo la definitiva es parcial y
-- refleja lo calificado hasta el momento. Al cerrar el curso todos los ítems tienen nota.
create or replace function public.calcular_definitiva(p_inscripcion uuid)
returns numeric language sql stable security definer set search_path = public, pg_temp as $$
  with nota_por_componente as (
    select c.id,
           c.peso as peso_componente,
           sum(n.valor * i.peso) / 100.0 as nota_componente
    from componentes_evaluacion c
    join items_calificables i on i.componente_id = c.id
    join notas n on n.item_id = i.id and n.inscripcion_id = p_inscripcion
    group by c.id, c.peso
  )
  select sum(nota_componente * peso_componente) / 100.0 from nota_por_componente;
$$;

-- Mantiene `inscripciones.definitiva` al día. Sin esto la columna quedaría siempre nula y la
-- vista de nota efectiva no diría nada.
create or replace function public.recalcular_definitiva()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_inscripcion uuid := coalesce(new.inscripcion_id, old.inscripcion_id);
begin
  update inscripciones
  set definitiva = public.calcular_definitiva(v_inscripcion)
  where id = v_inscripcion;
  return null;
end;
$$;

create trigger notas_recalcular_definitiva
  after insert or update or delete on notas
  for each row execute function public.recalcular_definitiva();

-- ---------------------------------------------------------------------------
-- Resultado de la habilitación
--
-- Se conserva siempre la calificación más alta: presentar la recuperación nunca puede dejar
-- al estudiante peor de como estaba. Un reemplazo puro desincentiva presentarse y produce
-- reclamaciones (adr/0006).
--
-- Se aplica sobre la DEFINITIVA COMPLETA del curso, no sobre el examen final: sobre un
-- componente que vale 15% el mecanismo no rescataría a nadie de la banda 2.0–2.9.
-- ---------------------------------------------------------------------------

create or replace function public.calcular_nota_habilitacion()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.estado = 'presentada' and new.nota_habilitacion is not null then
    new.nota_final := greatest(
      round(new.definitiva_original, 1),
      least(new.nota_habilitacion, new.tope_aplicado)
    );
  else
    new.nota_final := null;
  end if;
  return new;
end;
$$;

create trigger habilitaciones_calcular_nota_final
  before insert or update on habilitaciones
  for each row execute function public.calcular_nota_habilitacion();

-- `inscripciones.definitiva` NUNCA se sobrescribe. La nota resultante vive aquí, y la vista
-- resuelve cuál es la vigente. Es lo que permite responder a una reclamación dos años después
-- mostrando las tres cifras: original, habilitación y resultante.
--
-- `security_invoker` es imprescindible: sin él, la vista se ejecutaría con los privilegios de
-- su dueño y saltaría por encima de la RLS de las tablas que consulta. Sería una puerta
-- trasera al historial de notas de todo el instituto.
create or replace view v_nota_efectiva with (security_invoker = true) as
select i.id                                            as inscripcion_id,
       i.definitiva                                     as nota_periodo,
       h.nota_habilitacion,
       coalesce(h.nota_final, round(i.definitiva, 1))    as nota_efectiva,
       (h.id is not null)                               as hubo_habilitacion
from inscripciones i
left join habilitaciones h on h.inscripcion_id = i.id and h.estado = 'presentada';

-- ---------------------------------------------------------------------------
-- Validación de la estructura al abrir el curso
--
-- No es un `check` por fila: durante la configuración se pasa por estados intermedios donde
-- los pesos no suman. La comprobación se hace en el momento en que el curso se abre, que es
-- cuando la estructura tiene que estar completa.
--
-- El nombre lleva número para fijar el orden: los disparadores BEFORE se ejecutan por orden
-- alfabético, y 0006 añadirá `curso_10_aplicar_plantilla`, que debe correr ANTES que esta.
-- ---------------------------------------------------------------------------

create or replace function public.validar_estructura_curso()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_suma_componentes numeric(6, 2);
  v_componente_malo  text;
begin
  if new.estado <> 'abierto' or (tg_op = 'UPDATE' and old.estado = 'abierto') then
    return new;
  end if;

  select coalesce(sum(peso), 0) into v_suma_componentes
  from componentes_evaluacion where curso_id = new.id;

  if v_suma_componentes <> 100 then
    raise exception
      'Los componentes del curso suman %, y deben sumar 100. No se puede abrir.',
      v_suma_componentes
      using errcode = 'check_violation';
  end if;

  select c.nombre || ' suma ' || coalesce(sum(i.peso), 0) into v_componente_malo
  from componentes_evaluacion c
  left join items_calificables i on i.componente_id = c.id
  where c.curso_id = new.id
  group by c.id, c.nombre
  having coalesce(sum(i.peso), 0) <> 100
  limit 1;

  if v_componente_malo is not null then
    raise exception
      'Los ítems de un componente deben sumar 100: %. No se puede abrir el curso.',
      v_componente_malo
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger curso_20_validar_estructura
  before insert or update on cursos
  for each row execute function public.validar_estructura_curso();

-- ---------------------------------------------------------------------------
-- Auditoría de notas — la razón de ser de la tabla auditoria
-- ---------------------------------------------------------------------------

create trigger auditar_notas
  after insert or update or delete on notas
  for each row execute function public.registrar_auditoria();

-- ---------------------------------------------------------------------------
-- Índices
-- ---------------------------------------------------------------------------

create index on componentes_evaluacion (curso_id, corte);
create index on items_calificables (componente_id, orden);
create index on notas (inscripcion_id);
create index on notas (item_id);
create index on notas (registrada_por);
create index on notas (inscripcion_id) where publicada;
create index on habilitaciones (autorizada_por);
create index on habilitaciones (registrada_por);

-- ---------------------------------------------------------------------------
-- Funciones auxiliares para las políticas
-- ---------------------------------------------------------------------------

create or replace function app.curso_de_item(p_item uuid)
returns uuid language sql stable security definer set search_path = public, pg_temp as $$
  select c.curso_id
  from items_calificables i
  join componentes_evaluacion c on c.id = i.componente_id
  where i.id = p_item;
$$;

create or replace function app.curso_de_inscripcion(p_inscripcion uuid)
returns uuid language sql stable security definer set search_path = public, pg_temp as $$
  select curso_id from inscripciones where id = p_inscripcion;
$$;

create or replace function app.es_mi_inscripcion(p_inscripcion uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from inscripciones where id = p_inscripcion and estudiante_id = auth.uid()
  );
$$;

revoke execute on all functions in schema app from public, anon;
grant execute on all functions in schema app to authenticated;

-- ---------------------------------------------------------------------------
-- Privilegios y RLS
-- ---------------------------------------------------------------------------

alter table componentes_evaluacion enable row level security;
alter table items_calificables enable row level security;
alter table notas enable row level security;
alter table habilitaciones enable row level security;

revoke all on componentes_evaluacion, items_calificables, notas, habilitaciones
  from anon, authenticated;
grant select, insert, update on componentes_evaluacion, items_calificables, notas, habilitaciones
  to authenticated;

-- Estructura: el docente la ve pero no la toca. Si cada docente pudiera cambiar los pesos,
-- dos cursos de la misma materia dejarían de ser comparables (adr/0007).
create policy componentes_lectura_estudiante on componentes_evaluacion for select to authenticated
  using (app.esta_inscrito_en_curso(curso_id));

create policy componentes_lectura_docente on componentes_evaluacion for select to authenticated
  using (app.es_docente_del_curso(curso_id));

create policy componentes_escritura_coordinacion on componentes_evaluacion for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

create policy items_lectura_estudiante on items_calificables for select to authenticated
  using (app.esta_inscrito_en_curso(app.curso_de_item(id)));

create policy items_lectura_docente on items_calificables for select to authenticated
  using (app.es_docente_del_curso(app.curso_de_item(id)));

create policy items_escritura_coordinacion on items_calificables for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

-- El estudiante ve únicamente sus notas publicadas.
create policy notas_lectura_estudiante on notas for select to authenticated
  using (publicada and app.es_mi_inscripcion(inscripcion_id));

create policy notas_lectura_docente on notas for select to authenticated
  using (app.es_docente_del_curso(app.curso_de_item(item_id)));

create policy notas_lectura_coordinacion on notas for select to authenticated
  using (app.es_coordinacion());

-- El docente escribe solo en sus cursos y solo mientras estén abiertos. Al cerrar el
-- periodo, esta política deja de permitirle escribir: es lo que hace que el boletín siga
-- coincidiendo con la base de datos.
--
-- El `with check` no es decorativo: sin él, un docente podría reasignar una nota a una
-- inscripción de otro curso.
create policy notas_escritura_docente on notas for all to authenticated
  using (
    app.es_docente_del_curso(app.curso_de_item(item_id))
    and app.curso_abierto(app.curso_de_item(item_id))
  )
  with check (
    app.es_docente_del_curso(app.curso_de_item(item_id))
    and app.curso_abierto(app.curso_de_item(item_id))
    and app.curso_de_inscripcion(inscripcion_id) = app.curso_de_item(item_id)
  );

-- Coordinación corrige aun con el curso cerrado. Queda auditado.
create policy notas_escritura_coordinacion on notas for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

create policy habilitaciones_lectura_estudiante on habilitaciones for select to authenticated
  using (app.es_mi_inscripcion(inscripcion_id));

create policy habilitaciones_lectura_docente on habilitaciones for select to authenticated
  using (app.es_docente_del_curso(app.curso_de_inscripcion(inscripcion_id)));

-- Autorizar una habilitación es de coordinación, nunca del docente.
create policy habilitaciones_escritura_coordinacion on habilitaciones for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());
