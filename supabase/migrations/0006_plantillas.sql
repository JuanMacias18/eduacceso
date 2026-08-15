-- Encargo 02 · Migración 0006 — Plantillas de evaluación
--
-- Referencia: docs/modelo-datos.md (sección 5) · adr/0007.
--
-- La estructura de evaluación es la misma para las ~250 materias. Configurarla a mano en
-- cada curso que se abre cada cuatrimestre es inviable: son cientos de cursos al año, cada
-- uno con cuatro componentes y seis ítems.
--
-- La plantilla se COPIA al curso, no se referencia en vivo. Es la parte importante: si el
-- curso apuntara a la plantilla, cambiarla en marzo alteraría retroactivamente la ponderación
-- de un curso calificado y cerrado en enero. Las notas ya publicadas cambiarían de valor sin
-- que nadie tocara una nota. En un sistema académico eso es inaceptable.

create table plantillas_evaluacion (
  id                uuid primary key default gen_random_uuid(),
  -- null = aplica a cualquier programa.
  programa_id       uuid references programas (id),
  nombre            text not null,
  es_predeterminada boolean not null default false,
  activa            boolean not null default true,
  creada_en         timestamptz not null default now()
);

create table plantilla_componentes (
  id           uuid primary key default gen_random_uuid(),
  plantilla_id uuid not null references plantillas_evaluacion (id) on delete cascade,
  corte        smallint not null check (corte >= 1),
  nombre       text not null,
  tipo         tipo_componente not null,
  peso         numeric(5, 2) not null check (peso > 0 and peso <= 100),
  orden        smallint not null default 0,
  -- El nombre identifica al componente dentro de la plantilla. `aplicar_plantilla` empareja
  -- por nombre para copiar los ítems, así que esta restricción es la que hace la copia
  -- determinista.
  unique (plantilla_id, nombre)
);

create table plantilla_items (
  id                      uuid primary key default gen_random_uuid(),
  plantilla_componente_id uuid not null references plantilla_componentes (id) on delete cascade,
  nombre                  text not null,
  tipo                    tipo_item not null,
  peso                    numeric(5, 2) not null check (peso > 0 and peso <= 100),
  orden                   smallint not null default 0,
  unique (plantilla_componente_id, nombre)
);

alter table cursos
  add column plantilla_id             uuid references plantillas_evaluacion (id),
  -- Se marca cuando alguien edita la estructura de un curso concreto, para que coordinación
  -- vea de un vistazo cuáles se apartaron del estándar.
  add column estructura_personalizada boolean not null default false;

create index on plantilla_componentes (plantilla_id, orden);
create index on plantilla_items (plantilla_componente_id, orden);
create index on plantillas_evaluacion (programa_id);
create index on cursos (plantilla_id);
create index on cursos (plantilla_id) where estructura_personalizada;

-- ---------------------------------------------------------------------------
-- Copiar la plantilla al curso
--
-- Inserción masiva, no un ciclo fila por fila: abrir un cuatrimestre completo genera
-- cientos de filas y hacerlo de una en una convierte una operación en una espera.
-- ---------------------------------------------------------------------------

create or replace function public.aplicar_plantilla(p_curso uuid, p_plantilla uuid)
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_items integer;
begin
  if exists (select 1 from componentes_evaluacion where curso_id = p_curso) then
    raise exception
      'El curso ya tiene estructura de evaluación. Aplicar la plantilla encima duplicaría los componentes.'
      using errcode = 'check_violation';
  end if;

  -- Le dice al disparador de marcado que esto es la copia inicial, no una personalización.
  perform set_config('app.aplicando_plantilla', 'on', true);

  with componentes_nuevos as (
    insert into componentes_evaluacion (curso_id, corte, nombre, tipo, peso, orden)
    select p_curso, pc.corte, pc.nombre, pc.tipo, pc.peso, pc.orden
    from plantilla_componentes pc
    where pc.plantilla_id = p_plantilla
    returning id, nombre
  )
  insert into items_calificables (componente_id, nombre, tipo, peso, orden)
  select cn.id, pi.nombre, pi.tipo, pi.peso, pi.orden
  from componentes_nuevos cn
  join plantilla_componentes pc
    on pc.plantilla_id = p_plantilla and pc.nombre = cn.nombre
  join plantilla_items pi on pi.plantilla_componente_id = pc.id;

  get diagnostics v_items = row_count;

  -- Cuando esto corre dentro del disparador BEFORE de `cursos`, la fila del curso ya está
  -- siendo modificada por el comando en curso, y volver a tocarla desde aquí produce
  -- "tuple to be updated was already modified by an operation triggered by the current
  -- command". En ese caso la vinculación la hace el disparador, que tiene la fila en la mano.
  if pg_trigger_depth() = 0 then
    update cursos set plantilla_id = p_plantilla, estructura_personalizada = false
    where id = p_curso;
  end if;

  perform set_config('app.aplicando_plantilla', 'off', true);

  return v_items;
end;
$$;

-- ---------------------------------------------------------------------------
-- Marcado de estructura personalizada
--
-- Solo cuenta como personalización lo que ocurre DESPUÉS de la copia inicial. Por eso
-- `aplicar_plantilla` levanta la bandera mientras copia.
-- ---------------------------------------------------------------------------

create or replace function public.marcar_estructura_personalizada()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_curso uuid;
begin
  if coalesce(current_setting('app.aplicando_plantilla', true), 'off') = 'on' then
    return null;
  end if;

  if tg_table_name = 'componentes_evaluacion' then
    v_curso := coalesce(new.curso_id, old.curso_id);
  else
    v_curso := app.curso_de_item(coalesce(new.id, old.id));
    if v_curso is null then
      select c.curso_id into v_curso
      from componentes_evaluacion c
      where c.id = coalesce(new.componente_id, old.componente_id);
    end if;
  end if;

  update cursos set estructura_personalizada = true
  where id = v_curso and plantilla_id is not null and not estructura_personalizada;

  return null;
end;
$$;

create trigger componentes_marcar_personalizada
  after insert or update or delete on componentes_evaluacion
  for each row execute function public.marcar_estructura_personalizada();

create trigger items_marcar_personalizada
  after insert or update or delete on items_calificables
  for each row execute function public.marcar_estructura_personalizada();

-- ---------------------------------------------------------------------------
-- Aplicación automática al abrir el curso
--
-- El número del nombre fija el orden: los disparadores BEFORE se ejecutan por orden
-- alfabético, y `curso_20_validar_estructura` (0005) tiene que correr DESPUÉS de este.
-- Si se invirtieran, abrir un curso con plantilla fallaría siempre por falta de estructura.
-- ---------------------------------------------------------------------------

create or replace function public.aplicar_plantilla_al_abrir()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_plantilla uuid;
begin
  if new.estado <> 'abierto' or (tg_op = 'UPDATE' and old.estado = 'abierto') then
    return new;
  end if;

  if exists (select 1 from componentes_evaluacion where curso_id = new.id) then
    return new;
  end if;

  -- La plantilla explícita del curso manda; si no la hay, la predeterminada del programa;
  -- y si tampoco, la predeterminada global.
  select p.id into v_plantilla
  from plantillas_evaluacion p
  join materias m on m.id = new.materia_id
  where p.id = new.plantilla_id
     or (p.activa and p.es_predeterminada
         and (p.programa_id = m.programa_id or p.programa_id is null))
  order by (p.id = new.plantilla_id) desc, (p.programa_id is not null) desc
  limit 1;

  if v_plantilla is not null then
    perform public.aplicar_plantilla(new.id, v_plantilla);
    new.plantilla_id := v_plantilla;
  end if;

  return new;
end;
$$;

create trigger curso_10_aplicar_plantilla
  before insert or update on cursos
  for each row execute function public.aplicar_plantilla_al_abrir();

-- ---------------------------------------------------------------------------
-- Privilegios y RLS
-- ---------------------------------------------------------------------------

alter table plantillas_evaluacion enable row level security;
alter table plantilla_componentes enable row level security;
alter table plantilla_items enable row level security;

revoke all on plantillas_evaluacion, plantilla_componentes, plantilla_items
  from anon, authenticated;
grant select, insert, update on plantillas_evaluacion, plantilla_componentes, plantilla_items
  to authenticated;

-- La plantilla es configuración académica, no dato personal: quien tiene sesión puede
-- consultarla. Editarla es de coordinación — si cada docente pudiera cambiar la ponderación,
-- "estructura obligatoria" dejaría de significar algo (adr/0007).
create policy plantillas_lectura on plantillas_evaluacion for select to authenticated using (true);
create policy plantillas_escritura on plantillas_evaluacion for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

create policy plantilla_componentes_lectura on plantilla_componentes for select to authenticated
  using (true);
create policy plantilla_componentes_escritura on plantilla_componentes for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

create policy plantilla_items_lectura on plantilla_items for select to authenticated using (true);
create policy plantilla_items_escritura on plantilla_items for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

-- ---------------------------------------------------------------------------
-- Plantilla predeterminada — tomada de la Guía de Asignatura real
--
-- Los cortes 30/30/40 que reporta coordinación salen de aquí: el tercero es Unidad 3 (25)
-- más Examen Final (15). Es configuración del sistema, no dato de prueba: por eso va en la
-- migración y no en la semilla.
-- ---------------------------------------------------------------------------

insert into plantillas_evaluacion (id, programa_id, nombre, es_predeterminada, activa)
values ('00000000-1111-2222-3333-000000000001', null,
        'Estructura estándar EduAcceso', true, true);

insert into plantilla_componentes (id, plantilla_id, corte, nombre, tipo, peso, orden)
values
  ('00000000-1111-2222-3333-000000000011', '00000000-1111-2222-3333-000000000001',
   1, 'Unidad 1', 'unidad', 30, 1),
  ('00000000-1111-2222-3333-000000000012', '00000000-1111-2222-3333-000000000001',
   2, 'Unidad 2', 'unidad', 30, 2),
  ('00000000-1111-2222-3333-000000000013', '00000000-1111-2222-3333-000000000001',
   3, 'Unidad 3', 'unidad', 25, 3),
  ('00000000-1111-2222-3333-000000000014', '00000000-1111-2222-3333-000000000001',
   3, 'Examen Final Integrador', 'examen_final', 15, 4);

insert into plantilla_items (plantilla_componente_id, nombre, tipo, peso, orden)
values
  ('00000000-1111-2222-3333-000000000011', 'Actividad', 'actividad', 70, 1),
  ('00000000-1111-2222-3333-000000000011', 'Quiz', 'quiz', 30, 2),
  ('00000000-1111-2222-3333-000000000012', 'Actividad', 'actividad', 70, 1),
  ('00000000-1111-2222-3333-000000000012', 'Quiz', 'quiz', 30, 2),
  ('00000000-1111-2222-3333-000000000013', 'Actividad', 'actividad', 100, 1),
  ('00000000-1111-2222-3333-000000000014', 'Examen', 'examen', 100, 1);
