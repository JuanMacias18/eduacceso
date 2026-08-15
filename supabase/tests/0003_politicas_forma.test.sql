-- Prueba de aptitud: forma de las políticas RLS.
--
-- No comprueba qué deja pasar cada política —eso lo hacen las pruebas de aislamiento— sino
-- que ninguna esté mal construida de una forma que ya sabemos que es un agujero.

begin;

select plan(3);

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

select * from finish();

rollback;
