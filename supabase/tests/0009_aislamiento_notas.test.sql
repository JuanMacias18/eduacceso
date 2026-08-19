-- Aislamiento de NOTAS y habilitaciones.
--
-- Completa la prueba de 0004, que se escribio en la rebanada de RLS —antes de que `notas`
-- existiera— y por eso nunca llego a cubrir lo que el encargo pide primero: que un
-- estudiante no pueda leer las notas de otro.
--
-- El montaje usa el caso dificil, no el comodo: los dos estudiantes estan en el MISMO curso.
-- Separarlos por curso escondería el fallo, porque bastaria con filtrar por curso para
-- acertar. Aqui la politica tiene que discriminar por inscripcion.

begin;

select plan(13);

insert into auth.users (id, instance_id, aud, role, email)
values
  ('a9a9a9a9-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'notas.a@prueba.local'),
  ('a9a9a9a9-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'notas.b@prueba.local'),
  ('b9b9b9b9-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'notas.docente1@prueba.local'),
  ('b9b9b9b9-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'notas.docente2@prueba.local');

insert into perfiles (id, numero_documento, nombres, apellidos)
values
  ('a9a9a9a9-0000-0000-0000-000000000001', '6000000001', 'Aura', 'Estudiante'),
  ('a9a9a9a9-0000-0000-0000-000000000002', '6000000002', 'Bruno', 'Estudiante'),
  ('b9b9b9b9-0000-0000-0000-000000000001', '6000000003', 'Delia', 'Docente'),
  ('b9b9b9b9-0000-0000-0000-000000000002', '6000000004', 'Dimas', 'Docente');

insert into usuario_roles (usuario_id, rol)
values
  ('a9a9a9a9-0000-0000-0000-000000000001', 'estudiante'),
  ('a9a9a9a9-0000-0000-0000-000000000002', 'estudiante'),
  ('b9b9b9b9-0000-0000-0000-000000000001', 'docente'),
  ('b9b9b9b9-0000-0000-0000-000000000002', 'docente');

insert into programas (id, codigo, nombre, tipo, nota_minima_aprobatoria)
values ('c9000000-0000-0000-0000-000000000001', 'AIS', 'Programa aislamiento', 'tecnico', 3.0);

insert into periodos_programa (programa_id, orden, etiqueta, duracion_meses)
values ('c9000000-0000-0000-0000-000000000001', 1, 'Cuatrimestre 1', 4);

insert into materias (id, programa_id, periodo_orden, nombre)
values
  ('d9000000-0000-0000-0000-000000000001', 'c9000000-0000-0000-0000-000000000001', 1, 'Materia compartida'),
  ('d9000000-0000-0000-0000-000000000002', 'c9000000-0000-0000-0000-000000000001', 1, 'Materia ajena');

insert into cohortes (id, programa_id, nombre, municipio, departamento, fecha_inicio)
values ('e9000000-0000-0000-0000-000000000001', 'c9000000-0000-0000-0000-000000000001',
        'Cohorte aislamiento', 'Granada', 'Meta', current_date);

insert into matriculas (id, estudiante_id, cohorte_id)
values
  ('f9000000-0000-0000-0000-000000000001', 'a9a9a9a9-0000-0000-0000-000000000001',
   'e9000000-0000-0000-0000-000000000001'),
  ('f9000000-0000-0000-0000-000000000002', 'a9a9a9a9-0000-0000-0000-000000000002',
   'e9000000-0000-0000-0000-000000000001');

insert into cursos (id, cohorte_id, materia_id, docente_id, periodo_orden, estado)
values
  ('19000000-0000-0000-0000-000000000001', 'e9000000-0000-0000-0000-000000000001',
   'd9000000-0000-0000-0000-000000000001', 'b9b9b9b9-0000-0000-0000-000000000001', 1, 'borrador'),
  ('19000000-0000-0000-0000-000000000002', 'e9000000-0000-0000-0000-000000000001',
   'd9000000-0000-0000-0000-000000000002', 'b9b9b9b9-0000-0000-0000-000000000002', 1, 'borrador');

-- Abrirlos les aplica la plantilla estandar: cuatro componentes y seis items cada uno.
update cursos set estado = 'abierto'
where id in ('19000000-0000-0000-0000-000000000001', '19000000-0000-0000-0000-000000000002');

insert into inscripciones (id, curso_id, matricula_id, estudiante_id)
values
  ('29000000-0000-0000-0000-000000000001', '19000000-0000-0000-0000-000000000001',
   'f9000000-0000-0000-0000-000000000001', 'a9a9a9a9-0000-0000-0000-000000000001'),
  ('29000000-0000-0000-0000-000000000002', '19000000-0000-0000-0000-000000000001',
   'f9000000-0000-0000-0000-000000000002', 'a9a9a9a9-0000-0000-0000-000000000002');

-- A: una nota publicada (Actividad) y una sin publicar (Quiz). B: una publicada.
insert into notas (item_id, inscripcion_id, valor, publicada, registrada_por)
select i.id, '29000000-0000-0000-0000-000000000001', 4.2, (i.nombre = 'Actividad'),
       'b9b9b9b9-0000-0000-0000-000000000001'
from items_calificables i
join componentes_evaluacion c on c.id = i.componente_id
where c.curso_id = '19000000-0000-0000-0000-000000000001' and c.nombre = 'Unidad 1';

insert into notas (item_id, inscripcion_id, valor, publicada, registrada_por)
select i.id, '29000000-0000-0000-0000-000000000002', 2.4, true,
       'b9b9b9b9-0000-0000-0000-000000000001'
from items_calificables i
join componentes_evaluacion c on c.id = i.componente_id
where c.curso_id = '19000000-0000-0000-0000-000000000001' and c.nombre = 'Unidad 1'
  and i.nombre = 'Actividad';

insert into habilitaciones (inscripcion_id, definitiva_original, nota_habilitacion,
                            tope_aplicado, estado, autorizada_por)
values ('29000000-0000-0000-0000-000000000002', 2.4000, 3.5, 3.0, 'presentada',
        'b9b9b9b9-0000-0000-0000-000000000001');

-- ---------------------------------------------------------------------------
-- Estudiante A — companero de clase de B
-- ---------------------------------------------------------------------------

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"a9a9a9a9-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select is((select count(*)::int from notas), 1, 'A ve exactamente una nota: la suya publicada');

select is(
  (select count(*)::int from notas
   where inscripcion_id = '29000000-0000-0000-0000-000000000002'),
  0,
  'A NO ve las notas de B, aunque esten en el mismo curso'
);

-- Sin el flag `publicada`, el estudiante veria notas a medio digitar.
select is(
  (select count(*)::int from notas where not publicada),
  0,
  'A NO ve su propia nota mientras no este publicada'
);

select is((select valor from notas), 4.2, 'La nota que A ve es la suya, con su valor');

-- Publicarse las notas uno mismo seria el atajo evidente. El estudiante no tiene politica de
-- escritura sobre notas, asi que el UPDATE no alcanza ninguna fila.
update notas set publicada = true;

select is(
  (select count(*)::int from notas),
  1,
  'El UPDATE de A no publica nada: sigue viendo una sola nota'
);

select is(
  (select count(*)::int from habilitaciones),
  0,
  'A NO ve la habilitacion de B'
);

-- La vista lleva `security_invoker`: sin el se ejecutaria con los privilegios de su dueno y
-- seria una puerta trasera al historial de notas de todo el instituto.
select is(
  (select count(*)::int from v_nota_efectiva),
  1,
  'v_nota_efectiva respeta la RLS: A solo ve su propia fila'
);

-- ---------------------------------------------------------------------------
-- Estudiante B
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"a9a9a9a9-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

select is((select count(*)::int from notas), 1, 'B ve solo su nota');
select is((select valor from notas), 2.4, 'La nota que B ve es la suya');

select is(
  (select count(*)::int from habilitaciones),
  1,
  'B si ve su propia habilitacion'
);

select is(
  (select nota_efectiva from v_nota_efectiva
   where inscripcion_id = '29000000-0000-0000-0000-000000000002'),
  3.0,
  'B ve su nota efectiva con el tope de la habilitacion aplicado'
);

-- ---------------------------------------------------------------------------
-- Docentes
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"b9b9b9b9-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

select is(
  (select count(*)::int from notas),
  3,
  'El docente del curso ve las tres notas, publicadas y sin publicar'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"b9b9b9b9-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

select is(
  (select count(*)::int from notas),
  0,
  'El docente de otro curso NO ve ninguna nota'
);

select * from finish();

rollback;
