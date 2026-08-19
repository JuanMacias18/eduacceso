-- Prueba de aptitud: forma de las políticas RLS.
--
-- No comprueba qué deja pasar cada política —eso lo hacen las pruebas de aislamiento— sino
-- que ninguna esté mal construida de una forma que ya sabemos que es un agujero.

begin;

select plan(7);

-- `using` decide qué filas se pueden tocar; `with check` decide cómo pueden quedar. Sin
-- `with check`, un docente puede mover una nota a una inscripción de otro curso: la fila de
-- origen le pertenece, la de destino no, y nadie lo comprueba.
select is(
  (
    select coalesce(
      string_agg(tablename || '.' || policyname || ' (' || cmd || ')', ', ' order by tablename),
      ''
    )
    from pg_policies
    where schemaname = 'public' and cmd in ('INSERT', 'UPDATE', 'ALL') and with_check is null
  ),
  '',
  'Ninguna política de escritura sin with check'
);

-- Una tabla con RLS y cero políticas deniega todo. Es seguro, pero casi siempre significa
-- que alguien añadió la tabla y olvidó el resto.
select is(
  (
    select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relrowsecurity
      and not exists (
        select 1 from pg_policies p
        where p.schemaname = 'public' and p.tablename = c.relname
      )
  ),
  '',
  'Ninguna tabla con RLS se quedó sin políticas'
);

-- Las funciones que las políticas usan para mirar otras tablas tienen que ser
-- `security definer` con `search_path` fijo. Sin lo primero hay recursión; sin lo segundo,
-- se puede secuestrar la resolución de nombres desde una sesión.
select is(
  (
    select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
    from pg_proc p
    where p.pronamespace = 'app'::regnamespace
      and (not p.prosecdef or p.proconfig is null
           or not exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%'))
  ),
  '',
  'Toda función de app es security definer con search_path fijo'
);

-- ---------------------------------------------------------------------------
-- La capa que hay DEBAJO de la RLS: los privilegios de tabla.
--
-- Se descubrió por las malas que sin `grant select` las políticas ni se evalúan y toda
-- consulta muere con "permission denied". Estas tres comprobaciones convierten esa lección
-- en invariantes, para que las migraciones que vengan no puedan olvidarlo en silencio.
-- ---------------------------------------------------------------------------

-- `relkind in ('r','v')`: las VISTAS tambien. Se aprendio por las malas — v_nota_efectiva
-- se creo sin GRANT y quedo correcta e inservible a la vez, porque la comprobacion original
-- solo miraba tablas.
select is(
  (
    select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'v')
      and not has_table_privilege('authenticated', c.oid, 'SELECT')
  ),
  '',
  'Toda tabla y vista concede SELECT a authenticated (si no, la RLS ni llega a evaluarse)'
);

-- Una vista sin `security_invoker` se ejecuta con los privilegios de su dueno y salta por
-- encima de la RLS de las tablas que consulta. Es una puerta trasera con aspecto inocente:
-- el dia que alguien anada `v_boletin` sin esta opcion, expone las notas de todo el
-- instituto sin que ninguna politica se entere.
select is(
  (
    select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'v'
      and not coalesce(
        array_to_string(c.reloptions, ',') like '%security_invoker=true%', false)
  ),
  '',
  'Toda vista se ejecuta con security_invoker: ninguna elude la RLS de sus tablas'
);

-- Regla 6: nada se borra. El privilegio solo existe donde el modelo contempla el borrado, y
-- eso es una segunda barrera por debajo de la RLS: aunque aparezca una política `for all`
-- de más sobre matriculas o inscripciones, el DELETE sigue sin pasar.
select is(
  (
    select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname not in ('modulos', 'recursos', 'progreso_recurso')
      and has_table_privilege('authenticated', c.oid, 'DELETE')
  ),
  '',
  'Solo el contenido y el progreso admiten DELETE; los registros académicos no'
);

-- Aquí no hay nada público: todo el que consulta ha iniciado sesión.
select is(
  (
    select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'v')
      and (
        has_table_privilege('anon', c.oid, 'SELECT')
        or has_table_privilege('anon', c.oid, 'INSERT')
        or has_table_privilege('anon', c.oid, 'UPDATE')
        or has_table_privilege('anon', c.oid, 'DELETE')
      )
  ),
  '',
  'anon no tiene ningún privilegio sobre las tablas ni vistas del portal'
);

select * from finish();

rollback;
