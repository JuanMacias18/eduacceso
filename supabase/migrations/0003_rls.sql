-- Encargo 02 · Migración 0003 — Funciones auxiliares y políticas RLS
--
-- Referencia: docs/modelo-datos.md (sección 7) · docs/plan.md (5.2) · CLAUDE.md reglas 1-4.
--
-- Las tablas ya tienen RLS activa desde 0001, sin políticas: denegar por defecto. Aquí se
-- abren los caminos legítimos, y solo esos.
--
-- Dos reglas que gobiernan todo el archivo:
--
--   · Ninguna política de escritura sin `with check`. `using` decide qué filas se pueden
--     tocar; sin `with check`, un docente podría mover una nota a una inscripción de otro
--     curso — la fila de origen le pertenece, la de destino no, y nadie lo comprueba.
--
--   · Ninguna política consulta directamente una tabla con RLS. Eso produce recursión, y se
--     manifiesta como un timeout sin mensaje claro (regla 4). Todo lo que necesite mirar
--     otra tabla pasa por una función `security definer` del esquema `app`.

-- ---------------------------------------------------------------------------
-- Esquema app: funciones auxiliares
-- ---------------------------------------------------------------------------

create schema if not exists app;

-- El esquema no se expone por la API: solo lo usan las políticas.
grant usage on schema app to authenticated;

create or replace function app.tiene_rol(p_rol rol_usuario)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from usuario_roles where usuario_id = auth.uid() and rol = p_rol
  );
$$;

-- Coordinación y administración comparten casi todos los permisos de escritura. Tenerlo en
-- una función evita repetir el `or` en cuarenta políticas y equivocarse en una.
create or replace function app.es_coordinacion()
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from usuario_roles
    where usuario_id = auth.uid() and rol in ('coordinador', 'admin')
  );
$$;

create or replace function app.es_admin()
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from usuario_roles where usuario_id = auth.uid() and rol = 'admin'
  );
$$;

create or replace function app.es_docente_del_curso(p_curso uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from cursos where id = p_curso and docente_id = auth.uid());
$$;

create or replace function app.curso_abierto(p_curso uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from cursos where id = p_curso and estado = 'abierto');
$$;

-- Los docentes preparan el material antes de que el curso abra. Lo que el cierre bloquea es
-- volver a tocarlo, no prepararlo.
create or replace function app.curso_editable(p_curso uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from cursos where id = p_curso and estado <> 'cerrado');
$$;

create or replace function app.esta_inscrito_en_curso(p_curso uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from inscripciones
    where curso_id = p_curso and estudiante_id = auth.uid() and estado <> 'retirada'
  );
$$;

create or replace function app.esta_matriculado_en_cohorte(p_cohorte uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from matriculas
    where cohorte_id = p_cohorte and estudiante_id = auth.uid() and eliminado_en is null
  );
$$;

create or replace function app.curso_de_modulo(p_modulo uuid)
returns uuid language sql stable security definer set search_path = public, pg_temp as $$
  select curso_id from modulos where id = p_modulo;
$$;

create or replace function app.curso_de_recurso(p_recurso uuid)
returns uuid language sql stable security definer set search_path = public, pg_temp as $$
  select m.curso_id from recursos r join modulos m on m.id = r.modulo_id where r.id = p_recurso;
$$;

-- ¿Es una persona a la que este docente le da clase? Habilita la planilla sin abrirle el
-- directorio completo de estudiantes.
create or replace function app.es_estudiante_de_mis_cursos(p_persona uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1
    from inscripciones i
    join cursos c on c.id = i.curso_id
    where i.estudiante_id = p_persona and c.docente_id = auth.uid()
  );
$$;

-- Estas funciones eluden la RLS por definición. Que solo las invoquen sesiones autenticadas.
revoke execute on all functions in schema app from public, anon;
grant execute on all functions in schema app to authenticated;

-- ---------------------------------------------------------------------------
-- Privilegios de tabla — la capa que hay DEBAJO de la RLS
--
-- La RLS solo entra a decidir si el rol ya tiene el privilegio. Sin `grant select`, una
-- consulta muere con "permission denied for table" y las políticas ni se evalúan.
--
-- Esto se hace explícito a propósito, en vez de confiar en los privilegios por defecto del
-- proyecto: son comportamiento implícito que puede diferir entre la base local y la de
-- producción, y el síntoma —todo devuelve permission denied— empuja justo hacia el atajo que
-- prohíbe la regla 2, sacar la service_role key para "arreglarlo".
--
-- `anon` no recibe nada. Aquí no hay nada público: todo el que consulta ha iniciado sesión.
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select, insert, update on all tables in schema public to authenticated;

-- El borrado no se concede en general (regla 6: nada se borra). Solo el contenido de un
-- curso y la marca de progreso admiten desaparecer; los registros académicos usan `estado`
-- y `eliminado_en`. Que el privilegio no exista es una segunda barrera por debajo de la RLS:
-- aunque mañana alguien escriba una política `for all` de más, el DELETE sigue sin pasar.
grant delete on modulos, recursos, progreso_recurso to authenticated;

-- ---------------------------------------------------------------------------
-- perfiles
--
-- El estudiante puede corregir su contacto, no su identidad. La RLS es por fila, así que la
-- restricción por columna se resuelve con un trigger: es la única forma de decir "esta fila
-- sí, pero estas columnas no".
-- ---------------------------------------------------------------------------

create policy perfiles_lectura_propia on perfiles for select to authenticated
  using (id = auth.uid());

create policy perfiles_lectura_coordinacion on perfiles for select to authenticated
  using (app.es_coordinacion());

create policy perfiles_lectura_docente on perfiles for select to authenticated
  using (app.es_estudiante_de_mis_cursos(id));

create policy perfiles_actualizacion_propia on perfiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy perfiles_escritura_coordinacion on perfiles for all to authenticated
  using (app.es_coordinacion())
  with check (app.es_coordinacion());

create or replace function public.perfiles_proteger_identidad()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if app.es_coordinacion() then
    return new;
  end if;

  if new.tipo_documento is distinct from old.tipo_documento
     or new.numero_documento is distinct from old.numero_documento
     or new.nombres is distinct from old.nombres
     or new.apellidos is distinct from old.apellidos
     or new.fecha_nacimiento is distinct from old.fecha_nacimiento
     or new.activo is distinct from old.activo then
    raise exception
      'Solo coordinación puede cambiar los datos de identidad de un perfil'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

create trigger perfiles_proteger_identidad
  before update on perfiles
  for each row execute function public.perfiles_proteger_identidad();

-- ---------------------------------------------------------------------------
-- usuario_roles — conceder roles es de administración, nunca de coordinación
-- ---------------------------------------------------------------------------

create policy usuario_roles_lectura_propia on usuario_roles for select to authenticated
  using (usuario_id = auth.uid());

create policy usuario_roles_lectura_coordinacion on usuario_roles for select to authenticated
  using (app.es_coordinacion());

create policy usuario_roles_escritura_admin on usuario_roles for all to authenticated
  using (app.es_admin())
  with check (app.es_admin());

-- ---------------------------------------------------------------------------
-- Catálogo: programas, periodos_programa, materias
--
-- Es catálogo, no dato personal: cualquier sesión autenticada puede leerlo. Escribirlo es de
-- coordinación.
-- ---------------------------------------------------------------------------

create policy programas_lectura on programas for select to authenticated using (true);
create policy programas_escritura on programas for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

create policy periodos_lectura on periodos_programa for select to authenticated using (true);
create policy periodos_escritura on periodos_programa for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

create policy materias_lectura on materias for select to authenticated using (true);
create policy materias_escritura on materias for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

-- ---------------------------------------------------------------------------
-- cohortes
-- ---------------------------------------------------------------------------

create policy cohortes_lectura_propia on cohortes for select to authenticated
  using (app.esta_matriculado_en_cohorte(id));

create policy cohortes_lectura_coordinacion on cohortes for select to authenticated
  using (app.es_coordinacion());

create policy cohortes_lectura_docente on cohortes for select to authenticated
  using (exists (select 1 from cursos c where c.cohorte_id = cohortes.id and c.docente_id = auth.uid()));

create policy cohortes_escritura on cohortes for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

-- ---------------------------------------------------------------------------
-- matriculas — el registro maestro. Nunca se borra (regla 6): no hay política de delete.
-- ---------------------------------------------------------------------------

create policy matriculas_lectura_propia on matriculas for select to authenticated
  using (estudiante_id = auth.uid());

create policy matriculas_lectura_coordinacion on matriculas for select to authenticated
  using (app.es_coordinacion());

create policy matriculas_insercion on matriculas for insert to authenticated
  with check (app.es_coordinacion());

create policy matriculas_actualizacion on matriculas for update to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

-- ---------------------------------------------------------------------------
-- cursos
-- ---------------------------------------------------------------------------

create policy cursos_lectura_estudiante on cursos for select to authenticated
  using (app.esta_inscrito_en_curso(id));

create policy cursos_lectura_docente on cursos for select to authenticated
  using (docente_id = auth.uid());

create policy cursos_lectura_coordinacion on cursos for select to authenticated
  using (app.es_coordinacion());

-- La apertura y el cierre del periodo son de coordinación: es lo que hace que el cierre
-- signifique algo (plan.md 5.2).
create policy cursos_escritura_coordinacion on cursos for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

-- ---------------------------------------------------------------------------
-- inscripciones — nunca se borran (regla 6)
-- ---------------------------------------------------------------------------

create policy inscripciones_lectura_propia on inscripciones for select to authenticated
  using (estudiante_id = auth.uid());

create policy inscripciones_lectura_docente on inscripciones for select to authenticated
  using (app.es_docente_del_curso(curso_id));

create policy inscripciones_lectura_coordinacion on inscripciones for select to authenticated
  using (app.es_coordinacion());

create policy inscripciones_insercion on inscripciones for insert to authenticated
  with check (app.es_coordinacion());

create policy inscripciones_actualizacion on inscripciones for update to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

-- ---------------------------------------------------------------------------
-- modulos y recursos
--
-- El estudiante ve lo publicado de los cursos en los que está inscrito. El docente ve y
-- edita todo lo de los suyos, incluido el borrador, mientras el curso no esté cerrado.
-- ---------------------------------------------------------------------------

create policy modulos_lectura_estudiante on modulos for select to authenticated
  using (publicado and app.esta_inscrito_en_curso(curso_id));

create policy modulos_lectura_docente on modulos for select to authenticated
  using (app.es_docente_del_curso(curso_id));

create policy modulos_lectura_coordinacion on modulos for select to authenticated
  using (app.es_coordinacion());

create policy modulos_escritura_docente on modulos for all to authenticated
  using (app.es_docente_del_curso(curso_id) and app.curso_editable(curso_id))
  with check (app.es_docente_del_curso(curso_id) and app.curso_editable(curso_id));

create policy modulos_escritura_coordinacion on modulos for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

create policy recursos_lectura_estudiante on recursos for select to authenticated
  using (
    publicado
    and exists (
      select 1 from modulos m
      where m.id = recursos.modulo_id and m.publicado
        and app.esta_inscrito_en_curso(m.curso_id)
    )
  );

create policy recursos_lectura_docente on recursos for select to authenticated
  using (app.es_docente_del_curso(app.curso_de_modulo(modulo_id)));

create policy recursos_lectura_coordinacion on recursos for select to authenticated
  using (app.es_coordinacion());

create policy recursos_escritura_docente on recursos for all to authenticated
  using (
    app.es_docente_del_curso(app.curso_de_modulo(modulo_id))
    and app.curso_editable(app.curso_de_modulo(modulo_id))
  )
  with check (
    app.es_docente_del_curso(app.curso_de_modulo(modulo_id))
    and app.curso_editable(app.curso_de_modulo(modulo_id))
  );

create policy recursos_escritura_coordinacion on recursos for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

-- ---------------------------------------------------------------------------
-- progreso_recurso — lo único que el estudiante escribe, y solo lo suyo
-- ---------------------------------------------------------------------------

create policy progreso_lectura_propia on progreso_recurso for select to authenticated
  using (estudiante_id = auth.uid());

create policy progreso_lectura_docente on progreso_recurso for select to authenticated
  using (app.es_docente_del_curso(app.curso_de_recurso(recurso_id)));

create policy progreso_insercion_propia on progreso_recurso for insert to authenticated
  with check (
    estudiante_id = auth.uid()
    and app.esta_inscrito_en_curso(app.curso_de_recurso(recurso_id))
  );

create policy progreso_actualizacion_propia on progreso_recurso for update to authenticated
  using (estudiante_id = auth.uid())
  with check (estudiante_id = auth.uid());

-- ---------------------------------------------------------------------------
-- anuncios
-- ---------------------------------------------------------------------------

create policy anuncios_lectura_estudiante on anuncios for select to authenticated
  using (
    (curso_id is not null and app.esta_inscrito_en_curso(curso_id))
    or (cohorte_id is not null and app.esta_matriculado_en_cohorte(cohorte_id))
  );

create policy anuncios_lectura_docente on anuncios for select to authenticated
  using (curso_id is not null and app.es_docente_del_curso(curso_id));

create policy anuncios_lectura_coordinacion on anuncios for select to authenticated
  using (app.es_coordinacion());

create policy anuncios_escritura_docente on anuncios for all to authenticated
  using (curso_id is not null and app.es_docente_del_curso(curso_id) and autor_id = auth.uid())
  with check (curso_id is not null and app.es_docente_del_curso(curso_id) and autor_id = auth.uid());

create policy anuncios_escritura_coordinacion on anuncios for all to authenticated
  using (app.es_coordinacion()) with check (app.es_coordinacion());

-- ---------------------------------------------------------------------------
-- autorizaciones_datos
--
-- Un consentimiento es un hecho fechado: se registra y no se edita. Revocarlo se hace
-- registrando uno nuevo, no reescribiendo el anterior. Por eso no hay update ni delete.
-- ---------------------------------------------------------------------------

create policy autorizaciones_lectura_propia on autorizaciones_datos for select to authenticated
  using (titular_id = auth.uid());

create policy autorizaciones_lectura_coordinacion on autorizaciones_datos for select to authenticated
  using (app.es_coordinacion());

create policy autorizaciones_insercion on autorizaciones_datos for insert to authenticated
  with check (titular_id = auth.uid() or app.es_coordinacion());
