-- Prueba de aptitud: ninguna tabla sin RLS.
--
-- Es la primera de las cuatro verificaciones automáticas del plan (10.2). Existe porque la
-- RLS no se degrada de golpe: alguien añade una tabla, olvida la política, y nadie se entera
-- hasta que un estudiante ve las notas de otro.
--
-- La comparación es contra cadena vacía, no contra un conteo, para que el fallo diga QUÉ
-- tabla se quedó fuera en vez de decir "esperaba 0, obtuve 1".

begin;

select plan(2);

select is(
  (
    select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relrowsecurity
  ),
  '',
  'Toda tabla de public tiene RLS habilitada'
);

-- Que ninguna tabla fuerce la RLS es distinto de tenerla activa: sin `force`, el dueño de
-- la tabla la elude. Aquí solo se comprueba que existan tablas — si el esquema quedara
-- vacío por un error de migración, la prueba de arriba pasaría trivialmente y no diría nada.
select cmp_ok(
  (
    select count(*)::int
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  ),
  '>=',
  14,
  'El esquema tiene las tablas esperadas (la prueba anterior no pasa por vacío)'
);

select * from finish();

rollback;
