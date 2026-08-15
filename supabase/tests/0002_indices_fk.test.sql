-- Prueba de aptitud: ninguna foreign key sin índice (CLAUDE.md, regla 9).
--
-- Postgres no crea estos índices solo. Sin ellos, borrar o actualizar la fila referenciada
-- obliga a un recorrido secuencial de la tabla que apunta. A 200 estudiantes no se nota; a
-- 2.000, sí — y para entonces la tabla ya está en producción.
--
-- Una foreign key se considera cubierta si existe un índice cuyas PRIMERAS columnas son
-- exactamente las de la foreign key, en cualquier orden. Eso incluye los índices de claves
-- primarias y de `unique`: si ya sirven, crear otro igual solo encarece cada escritura.
--
-- Ojo con `pg_index.indkey`: al convertirlo a smallint[] el array empieza en 0, no en 1.
-- De ahí el corte [0 : n-1].

begin;

select plan(2);

select is(
  (
    select coalesce(string_agg(descripcion, ', ' order by descripcion), '')
    from (
      select c.conrelid::regclass::text || '.' || c.conname as descripcion
      from pg_constraint c
      where c.contype = 'f'
        and c.connamespace = 'public'::regnamespace
        and not exists (
          select 1
          from pg_index i
          where i.indrelid = c.conrelid
            and (
              select array_agg(k order by k)
              from unnest((i.indkey::smallint[])[0:array_length(c.conkey, 1) - 1]) as k
            ) = (select array_agg(k order by k) from unnest(c.conkey) as k)
        )
    ) as sin_cobertura
  ),
  '',
  'Toda foreign key tiene un índice que la cubre'
);

-- Igual que en la prueba de RLS: si no hubiera foreign keys, la comprobación de arriba
-- pasaría trivialmente sin decir nada.
select cmp_ok(
  (
    select count(*)::int
    from pg_constraint
    where contype = 'f' and connamespace = 'public'::regnamespace
  ),
  '>=',
  20,
  'El esquema tiene las foreign keys esperadas (la prueba anterior no pasa por vacío)'
);

select * from finish();

rollback;
