-- Plantillas de evaluación (adr/0007).
--
-- Lo que estas pruebas defienden: que la plantilla se COPIA y no se referencia. Si el curso
-- apuntara a la plantilla en vivo, cambiarla en marzo alteraría retroactivamente la
-- ponderación de un curso calificado y cerrado en enero, y las notas ya publicadas
-- cambiarían de valor sin que nadie tocara una nota.

begin;

select plan(11);

insert into auth.users (id, instance_id, aud, role, email)
values ('c7c7c7c7-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'plant.coordina@prueba.local');

insert into perfiles (id, numero_documento, nombres, apellidos)
values ('c7c7c7c7-0000-0000-0000-000000000001', '5000000001', 'Pilar', 'Coordina');

insert into usuario_roles (usuario_id, rol)
values ('c7c7c7c7-0000-0000-0000-000000000001', 'coordinador');

insert into programas (id, codigo, nombre, tipo, nota_minima_aprobatoria)
values ('c7000000-0000-0000-0000-000000000001', 'PLA', 'Programa plantillas', 'tecnico', 3.0);

insert into periodos_programa (programa_id, orden, etiqueta, duracion_meses)
values ('c7000000-0000-0000-0000-000000000001', 1, 'Cuatrimestre 1', 4);

insert into materias (id, programa_id, periodo_orden, nombre)
values
  ('d7000000-0000-0000-0000-000000000001', 'c7000000-0000-0000-0000-000000000001', 1, 'Materia A'),
  ('d7000000-0000-0000-0000-000000000002', 'c7000000-0000-0000-0000-000000000001', 1, 'Materia B');

insert into cohortes (id, programa_id, nombre, municipio, departamento, fecha_inicio)
values ('e7000000-0000-0000-0000-000000000001', 'c7000000-0000-0000-0000-000000000001',
        'Cohorte plantillas', 'Yopal', 'Casanare', current_date);

insert into cursos (id, cohorte_id, materia_id, periodo_orden, estado)
values
  ('17000000-0000-0000-0000-000000000001', 'e7000000-0000-0000-0000-000000000001',
   'd7000000-0000-0000-0000-000000000001', 1, 'borrador'),
  ('17000000-0000-0000-0000-000000000002', 'e7000000-0000-0000-0000-000000000001',
   'd7000000-0000-0000-0000-000000000002', 1, 'borrador');

-- ---------------------------------------------------------------------------
-- Abrir el curso aplica la plantilla predeterminada y valida la estructura
-- ---------------------------------------------------------------------------

select lives_ok(
  $$update cursos set estado = 'abierto' where id = '17000000-0000-0000-0000-000000000001'$$,
  'Un curso sin estructura se abre: la plantilla predeterminada se aplica sola'
);

select is(
  (select count(*)::int from componentes_evaluacion
   where curso_id = '17000000-0000-0000-0000-000000000001'),
  4,
  'Se copiaron los cuatro componentes de la guía'
);

select is(
  (select count(*)::int from items_calificables i
   join componentes_evaluacion c on c.id = i.componente_id
   where c.curso_id = '17000000-0000-0000-0000-000000000001'),
  6,
  'Se copiaron los seis ítems'
);

select is(
  (select sum(peso) from componentes_evaluacion
   where curso_id = '17000000-0000-0000-0000-000000000001'),
  100.00,
  'Los componentes copiados suman 100'
);

-- La copia inicial no es una personalización.
select is(
  (select estructura_personalizada from cursos where id = '17000000-0000-0000-0000-000000000001'),
  false,
  'Copiar la plantilla no marca el curso como personalizado'
);

-- ---------------------------------------------------------------------------
-- Independencia: se edita el peso en UN curso
-- ---------------------------------------------------------------------------

update cursos set estado = 'abierto' where id = '17000000-0000-0000-0000-000000000002';

update componentes_evaluacion set peso = 40
where curso_id = '17000000-0000-0000-0000-000000000001' and nombre = 'Unidad 1';

select is(
  (select peso from plantilla_componentes
   where plantilla_id = '00000000-1111-2222-3333-000000000001' and nombre = 'Unidad 1'),
  30.00,
  'La PLANTILLA no cambió al editar el curso'
);

select is(
  (select peso from componentes_evaluacion
   where curso_id = '17000000-0000-0000-0000-000000000002' and nombre = 'Unidad 1'),
  30.00,
  'El OTRO curso no cambió al editar el primero'
);

select is(
  (select estructura_personalizada from cursos where id = '17000000-0000-0000-0000-000000000001'),
  true,
  'El curso editado queda marcado como personalizado'
);

select is(
  (select estructura_personalizada from cursos where id = '17000000-0000-0000-0000-000000000002'),
  false,
  'El curso no editado sigue sin marcar'
);

-- ---------------------------------------------------------------------------
-- Y al revés: cambiar la plantilla no toca los cursos ya abiertos
-- ---------------------------------------------------------------------------

update plantilla_componentes set peso = 50
where plantilla_id = '00000000-1111-2222-3333-000000000001' and nombre = 'Unidad 2';

select is(
  (select peso from componentes_evaluacion
   where curso_id = '17000000-0000-0000-0000-000000000002' and nombre = 'Unidad 2'),
  30.00,
  'Cambiar la plantilla NO altera un curso ya abierto — es la razón de copiar'
);

-- ---------------------------------------------------------------------------
-- Aplicarla dos veces duplicaría la estructura
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select public.aplicar_plantilla('17000000-0000-0000-0000-000000000001',
                                    '00000000-1111-2222-3333-000000000001')$$,
  '23514',
  null,
  'Aplicar la plantilla sobre un curso que ya tiene estructura se rechaza'
);

select * from finish();

rollback;
