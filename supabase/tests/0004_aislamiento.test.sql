-- LA prueba que no es negociable (docs/plan.md 5.3).
--
-- Crea dos estudiantes de cohortes distintas y dos docentes de cursos distintos, se
-- autentica como cada uno e intenta leer lo del otro. Toda consulta debe devolver cero filas.
--
-- Sin esto la RLS se degrada en silencio: alguien añade una tabla, olvida la política, y
-- nadie se entera hasta que un estudiante ve las notas de otro.
--
-- Los datos se crean aquí dentro y mueren con el `rollback`. Depender de supabase/seed.sql
-- ataría esta prueba a que la semilla no cambie, y la semilla va a cambiar.

begin;

select plan(14);

-- ---------------------------------------------------------------------------
-- Montaje. Se ejecuta como superusuario, antes de bajar a `authenticated`.
-- ---------------------------------------------------------------------------

insert into auth.users (id, instance_id, aud, role, email)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'estudiante.a@prueba.local'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'estudiante.b@prueba.local'),
  ('bbbbbbbb-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'docente.uno@prueba.local'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'docente.dos@prueba.local');

insert into perfiles (id, numero_documento, nombres, apellidos)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '1000000001', 'Ana', 'Estudiante'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '1000000002', 'Beto', 'Estudiante'),
  ('bbbbbbbb-0000-0000-0000-000000000001', '2000000001', 'Dora', 'Docente'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '2000000002', 'Diego', 'Docente');

insert into usuario_roles (usuario_id, rol)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'estudiante'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'estudiante'),
  ('bbbbbbbb-0000-0000-0000-000000000001', 'docente'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'docente');

insert into programas (id, codigo, nombre, tipo, nota_minima_aprobatoria)
values ('cccccccc-0000-0000-0000-000000000001', 'PRB', 'Programa de prueba', 'tecnico', 3.0);

insert into periodos_programa (programa_id, orden, etiqueta, duracion_meses)
values ('cccccccc-0000-0000-0000-000000000001', 1, 'Cuatrimestre 1', 4);

insert into materias (id, programa_id, periodo_orden, nombre)
values
  ('dddddddd-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', 1, 'Materia Uno'),
  ('dddddddd-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000001', 1, 'Materia Dos');

-- Dos cohortes distintas: es la separación que la prueba tiene que demostrar.
insert into cohortes (id, programa_id, nombre, municipio, departamento, fecha_inicio, estado)
values
  ('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001',
   'Cohorte A', 'Puerto López', 'Meta', current_date, 'activa'),
  ('eeeeeeee-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000001',
   'Cohorte B', 'Yopal', 'Casanare', current_date, 'activa');

insert into matriculas (id, estudiante_id, cohorte_id)
values
  ('ffffffff-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   'eeeeeeee-0000-0000-0000-000000000001'),
  ('ffffffff-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002',
   'eeeeeeee-0000-0000-0000-000000000002');

insert into cursos (id, cohorte_id, materia_id, docente_id, periodo_orden, estado)
values
  ('11111111-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001',
   'dddddddd-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 1, 'borrador'),
  ('11111111-0000-0000-0000-000000000002', 'eeeeeeee-0000-0000-0000-000000000002',
   'dddddddd-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'borrador');

insert into inscripciones (id, curso_id, matricula_id, estudiante_id)
values
  ('22222222-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001',
   'ffffffff-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001'),
  ('22222222-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000002',
   'ffffffff-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002');

insert into modulos (id, curso_id, titulo, publicado)
values
  ('33333333-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Unidad 1 de A', true),
  ('33333333-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000002', 'Unidad 1 de B', true);

insert into recursos (id, modulo_id, tipo, titulo, youtube_id, publicado)
values
  ('44444444-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001',
   'video_youtube', 'Clase de A', 'video-ficticio-a', true),
  ('44444444-0000-0000-0000-000000000002', '33333333-0000-0000-0000-000000000002',
   'video_youtube', 'Clase de B', 'video-ficticio-b', true);

-- ---------------------------------------------------------------------------
-- Estudiante A
-- ---------------------------------------------------------------------------

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select is((select count(*)::int from matriculas), 1, 'A ve su matrícula');
select is(
  (select count(*)::int from matriculas
   where estudiante_id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  0,
  'A NO ve la matrícula de B'
);

select is((select count(*)::int from inscripciones), 1, 'A ve su inscripción');
select is(
  (select count(*)::int from inscripciones
   where estudiante_id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  0,
  'A NO ve la inscripción de B'
);

select is((select count(*)::int from cursos), 1, 'A ve solo su curso');
select is((select count(*)::int from modulos), 1, 'A ve solo el contenido de su curso');
select is((select count(*)::int from recursos), 1, 'A ve solo los recursos de su curso');
select is((select count(*)::int from cohortes), 1, 'A ve solo su cohorte');

-- El perfil ajeno es dato personal de un menor potencial: no se asoma ni el nombre.
select is(
  (select count(*)::int from perfiles
   where id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  0,
  'A NO ve el perfil de B'
);

-- Escribir progreso sobre un recurso de otro curso debe ser imposible, no solo invisible.
select throws_ok(
  $$insert into progreso_recurso (estudiante_id, recurso_id)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '44444444-0000-0000-0000-000000000002')$$,
  '42501',
  null,
  'A NO puede marcar progreso en un recurso de un curso ajeno'
);

-- Suplantar a B al escribir tampoco: para eso está el `with check`.
select throws_ok(
  $$insert into progreso_recurso (estudiante_id, recurso_id)
    values ('aaaaaaaa-0000-0000-0000-000000000002', '44444444-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'A NO puede registrar progreso a nombre de B'
);

-- ---------------------------------------------------------------------------
-- Docente 1
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select is((select count(*)::int from cursos), 1, 'El docente 1 ve solo su curso');
select is(
  (select count(*)::int from inscripciones
   where curso_id = '11111111-0000-0000-0000-000000000002'),
  0,
  'El docente 1 NO ve los inscritos del curso del docente 2'
);

-- Ve a su estudiante, no al ajeno: la planilla no puede abrir el directorio completo.
select is(
  (select count(*)::int from perfiles
   where id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  0,
  'El docente 1 NO ve el perfil de un estudiante que no es suyo'
);

select * from finish();

rollback;
