-- La auditoría es lo que permite responder a una reclamación de nota dos años después.
-- Estas pruebas comprueban las tres propiedades de las que depende esa promesa:
-- que registra, que registra QUIÉN, y que nadie puede reescribirla.

begin;

select plan(9);

insert into auth.users (id, instance_id, aud, role, email)
values
  ('aaaaaaaa-1111-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'aud.estudiante@prueba.local'),
  ('cccccccc-1111-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'aud.coordina@prueba.local');

insert into perfiles (id, numero_documento, nombres, apellidos)
values
  ('aaaaaaaa-1111-0000-0000-000000000001', '3000000001', 'Aud', 'Estudiante'),
  ('cccccccc-1111-0000-0000-000000000001', '3000000002', 'Coro', 'Coordina');

insert into usuario_roles (usuario_id, rol)
values
  ('aaaaaaaa-1111-0000-0000-000000000001', 'estudiante'),
  ('cccccccc-1111-0000-0000-000000000001', 'coordinador');

insert into programas (id, codigo, nombre, tipo, nota_minima_aprobatoria)
values ('cccccccc-1111-0000-0000-000000000002', 'AUD', 'Programa auditado', 'tecnico', 3.0);

insert into periodos_programa (programa_id, orden, etiqueta, duracion_meses)
values ('cccccccc-1111-0000-0000-000000000002', 1, 'Cuatrimestre 1', 4);

insert into cohortes (id, programa_id, nombre, municipio, departamento, fecha_inicio)
values ('eeeeeeee-1111-0000-0000-000000000001', 'cccccccc-1111-0000-0000-000000000002',
        'Cohorte auditada', 'Villavicencio', 'Meta', current_date);

-- ---------------------------------------------------------------------------
-- Actúa coordinación: matricula a alguien y luego lo aplaza.
-- ---------------------------------------------------------------------------

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"cccccccc-1111-0000-0000-000000000001","role":"authenticated"}',
  true
);

insert into matriculas (id, estudiante_id, cohorte_id)
values ('ffffffff-1111-0000-0000-000000000001', 'aaaaaaaa-1111-0000-0000-000000000001',
        'eeeeeeee-1111-0000-0000-000000000001');

update matriculas set estado = 'aplazada'
where id = 'ffffffff-1111-0000-0000-000000000001';

-- ---------------------------------------------------------------------------
-- Lo que quedó registrado
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from auditoria
   where tabla = 'matriculas' and registro_id = 'ffffffff-1111-0000-0000-000000000001'),
  2,
  'Se registraron el alta y el cambio de estado'
);

select is(
  (select accion from auditoria
   where registro_id = 'ffffffff-1111-0000-0000-000000000001' order by ocurrido_en, id limit 1),
  'INSERT',
  'El primer asiento es el alta'
);

-- Sin el autor, la auditoría no sirve para responder una reclamación.
select is(
  (select actor_id from auditoria
   where registro_id = 'ffffffff-1111-0000-0000-000000000001' order by id desc limit 1),
  'cccccccc-1111-0000-0000-000000000001'::uuid,
  'Queda registrado QUIÉN hizo el cambio'
);

select is(
  (select antes ->> 'estado' from auditoria
   where registro_id = 'ffffffff-1111-0000-0000-000000000001' and accion = 'UPDATE'),
  'activa',
  'Se conserva el valor anterior'
);

select is(
  (select despues ->> 'estado' from auditoria
   where registro_id = 'ffffffff-1111-0000-0000-000000000001' and accion = 'UPDATE'),
  'aplazada',
  'Se conserva el valor nuevo'
);

-- Una planilla que reguarda la fila entera al salir de cada campo no debe llenar la
-- auditoría de asientos vacíos: enterrarían los cambios reales.
update matriculas set estado = 'aplazada'
where id = 'ffffffff-1111-0000-0000-000000000001';

select is(
  (select count(*)::int from auditoria
   where registro_id = 'ffffffff-1111-0000-0000-000000000001'),
  2,
  'Un UPDATE que no cambia nada no deja asiento'
);

-- ---------------------------------------------------------------------------
-- La auditoría no se puede reescribir. Si se pudiera, no probaría nada.
-- ---------------------------------------------------------------------------

select throws_ok(
  $$update auditoria set actor_id = null$$,
  '42501',
  null,
  'Ni coordinación puede alterar un asiento de auditoría'
);

select throws_ok(
  $$delete from auditoria$$,
  '42501',
  null,
  'Ni coordinación puede borrar un asiento de auditoría'
);

-- ---------------------------------------------------------------------------
-- Un estudiante no ve la auditoría de nadie, ni la suya.
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-1111-0000-0000-000000000001","role":"authenticated"}',
  true
);

select is(
  (select count(*)::int from auditoria),
  0,
  'El estudiante no ve la auditoría'
);

select * from finish();

rollback;
