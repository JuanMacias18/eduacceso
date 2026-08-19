-- Encargo 02 · Migración 0007 — Corrección de la apertura de curso
--
-- Corrige un defecto de 0006. NO se edita 0006: las migraciones se corrigen con una
-- migración nueva (CLAUDE.md regla 7, AGENT_LOOP condición de parada 3).
--
-- El defecto: `curso_10_aplicar_plantilla` estaba declarado `before insert or update`. En un
-- INSERT, el disparador BEFORE corre ANTES de que exista la fila del curso, así que copiar la
-- plantilla intenta insertar componentes que apuntan a un curso todavía inexistente y la
-- clave foránea lo rechaza:
--
--     insert or update on table "componentes_evaluacion" violates foreign key constraint
--
-- Un error de clave foránea filtrando detalles de implementación es la peor forma de
-- comunicar "los cursos se crean en borrador y se abren después".

drop trigger curso_10_aplicar_plantilla on cursos;

-- Solo en UPDATE. Es además el flujo real: `cursos.estado` nace en 'borrador' y coordinación
-- lo abre cuando el periodo empieza.
create trigger curso_10_aplicar_plantilla
  before update on cursos
  for each row execute function public.aplicar_plantilla_al_abrir();

-- Y que el intento de crear un curso ya abierto diga por qué no, en vez de dejar que la
-- validación de pesos responda "los componentes suman 0", que es cierto pero no ayuda.
create or replace function public.validar_estructura_curso()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_suma_componentes numeric(6, 2);
  v_componente_malo  text;
begin
  if new.estado <> 'abierto' or (tg_op = 'UPDATE' and old.estado = 'abierto') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    raise exception
      'Un curso se crea en borrador y se abre después: al abrirlo se le aplica la plantilla de evaluación.'
      using errcode = 'check_violation';
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
