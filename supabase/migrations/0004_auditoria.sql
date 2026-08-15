-- Encargo 02 · Migración 0004 — Auditoría
--
-- Referencia: docs/modelo-datos.md (sección 6) · docs/plan.md (4.3).
--
-- "La diferencia entre un sistema académico y una hoja de cálculo compartida": cuando un
-- estudiante reclame una nota dentro de dos años, tiene que existir el registro de quién la
-- puso, cuándo, y qué valor tenía antes.
--
-- `notas` todavía no existe — llega en 0005 — así que aquí se deja la función y se enganchan
-- las tres tablas que ya están. 0005 engancha `notas` a esta misma función.

create table auditoria (
  id          bigserial primary key,
  tabla       text not null,
  registro_id uuid not null,
  accion      text not null check (accion in ('INSERT', 'UPDATE', 'DELETE')),
  -- Nulo cuando el cambio no viene de una sesión de usuario (una Edge Function con
  -- service_role, una migración). Registrarlo como nulo es más honesto que inventar un autor.
  actor_id    uuid,
  antes       jsonb,
  despues     jsonb,
  ocurrido_en timestamptz not null default now()
);

-- El acceso típico es "dame la historia de esta fila, lo más reciente primero".
create index on auditoria (tabla, registro_id, ocurrido_en desc);
create index on auditoria (actor_id, ocurrido_en desc);

-- ---------------------------------------------------------------------------
-- El disparador
--
-- `security definer` es imprescindible: quien provoca el cambio NO tiene privilegio de
-- escritura sobre `auditoria`, y no debe tenerlo. Si un docente pudiera insertar en la tabla
-- de auditoría, podría fabricar un rastro — y entonces el rastro no prueba nada.
-- ---------------------------------------------------------------------------

create or replace function public.registrar_auditoria()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_antes   jsonb := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
  v_despues jsonb := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
begin
  -- Un UPDATE que no cambia nada no es un hecho que valga la pena guardar. Sin este filtro,
  -- una planilla que reguarda toda la fila al salir del campo llena la auditoría de ruido y
  -- entierra los cambios reales.
  if tg_op = 'UPDATE' and v_antes is not distinct from v_despues then
    return null;
  end if;

  insert into auditoria (tabla, registro_id, accion, actor_id, antes, despues)
  values (
    tg_table_name,
    coalesce((v_despues ->> 'id')::uuid, (v_antes ->> 'id')::uuid),
    tg_op,
    auth.uid(),
    v_antes,
    v_despues
  );

  return null;
end;
$$;

create trigger auditar_matriculas
  after insert or update or delete on matriculas
  for each row execute function public.registrar_auditoria();

create trigger auditar_inscripciones
  after insert or update or delete on inscripciones
  for each row execute function public.registrar_auditoria();

create trigger auditar_cursos
  after insert or update or delete on cursos
  for each row execute function public.registrar_auditoria();

-- ---------------------------------------------------------------------------
-- Privilegios y RLS
--
-- La auditoría se lee, no se escribe: se alimenta sola por disparador. Que `authenticated`
-- no tenga INSERT, UPDATE ni DELETE no es una restricción incómoda, es lo que hace que el
-- registro sirva como prueba.
-- ---------------------------------------------------------------------------

alter table auditoria enable row level security;

revoke all on auditoria from anon, authenticated;
grant select on auditoria to authenticated;

create policy auditoria_lectura_coordinacion on auditoria for select to authenticated
  using (app.es_coordinacion());
