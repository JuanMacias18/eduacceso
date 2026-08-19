-- Evaluación de dos niveles, habilitaciones y aritmética de notas.
--
-- La estructura sembrada es la de la Guía de Asignatura real (adr/0006):
--
--   Unidad 1                  corte 1   30%   Actividad 70 · Quiz 30
--   Unidad 2                  corte 2   30%   Actividad 70 · Quiz 30
--   Unidad 3                  corte 3   25%   Actividad 100
--   Examen Final Integrador   corte 3   15%   Examen 100
--
-- Los cortes 30/30/40 salen de ahí: el tercero es Unidad 3 (25) más Examen Final (15).

begin;

select plan(17);

-- ---------------------------------------------------------------------------
-- Montaje
-- ---------------------------------------------------------------------------

insert into auth.users (id, instance_id, aud, role, email)
values
  ('a5a5a5a5-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'eval.estudiante@prueba.local'),
  ('b5b5b5b5-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'eval.docente@prueba.local'),
  ('c5c5c5c5-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'eval.coordina@prueba.local');

insert into perfiles (id, numero_documento, nombres, apellidos)
values
  ('a5a5a5a5-0000-0000-0000-000000000001', '4000000001', 'Elsa', 'Estudiante'),
  ('b5b5b5b5-0000-0000-0000-000000000001', '4000000002', 'Darío', 'Docente'),
  ('c5c5c5c5-0000-0000-0000-000000000001', '4000000003', 'Karen', 'Coordina');

insert into usuario_roles (usuario_id, rol)
values
  ('a5a5a5a5-0000-0000-0000-000000000001', 'estudiante'),
  ('b5b5b5b5-0000-0000-0000-000000000001', 'docente'),
  ('c5c5c5c5-0000-0000-0000-000000000001', 'coordinador');

insert into programas (id, codigo, nombre, tipo, nota_minima_aprobatoria)
values ('c5000000-0000-0000-0000-000000000001', 'SOL', 'Soldador y Oxicortador', 'tecnico', 3.0);

insert into periodos_programa (programa_id, orden, etiqueta, duracion_meses)
values ('c5000000-0000-0000-0000-000000000001', 1, 'Cuatrimestre 1', 4);

insert into materias (id, programa_id, periodo_orden, nombre)
values
  ('d5000000-0000-0000-0000-000000000001', 'c5000000-0000-0000-0000-000000000001', 1,
   'Materiales y Metalurgia Básica'),
  ('d5000000-0000-0000-0000-000000000002', 'c5000000-0000-0000-0000-000000000001', 1,
   'Materia con estructura rota');

insert into cohortes (id, programa_id, nombre, municipio, departamento, fecha_inicio, estado)
values ('e5000000-0000-0000-0000-000000000001', 'c5000000-0000-0000-0000-000000000001',
        'Puerto López 2026-1', 'Puerto López', 'Meta', current_date, 'activa');

insert into matriculas (id, estudiante_id, cohorte_id)
values ('f5000000-0000-0000-0000-000000000001', 'a5a5a5a5-0000-0000-0000-000000000001',
        'e5000000-0000-0000-0000-000000000001');

insert into cursos (id, cohorte_id, materia_id, docente_id, periodo_orden, estado)
values ('15000000-0000-0000-0000-000000000001', 'e5000000-0000-0000-0000-000000000001',
        'd5000000-0000-0000-0000-000000000001', 'b5b5b5b5-0000-0000-0000-000000000001',
        1, 'borrador');

insert into inscripciones (id, curso_id, matricula_id, estudiante_id)
values ('25000000-0000-0000-0000-000000000001', '15000000-0000-0000-0000-000000000001',
        'f5000000-0000-0000-0000-000000000001', 'a5a5a5a5-0000-0000-0000-000000000001');

insert into componentes_evaluacion (id, curso_id, corte, nombre, tipo, peso, orden)
values
  ('35000000-0000-0000-0000-000000000001', '15000000-0000-0000-0000-000000000001', 1,
   'Unidad 1', 'unidad', 30, 1),
  ('35000000-0000-0000-0000-000000000002', '15000000-0000-0000-0000-000000000001', 2,
   'Unidad 2', 'unidad', 30, 2),
  ('35000000-0000-0000-0000-000000000003', '15000000-0000-0000-0000-000000000001', 3,
   'Unidad 3', 'unidad', 25, 3),
  ('35000000-0000-0000-0000-000000000004', '15000000-0000-0000-0000-000000000001', 3,
   'Examen Final Integrador', 'examen_final', 15, 4);

insert into items_calificables (id, componente_id, nombre, tipo, peso, orden)
values
  ('45000000-0000-0000-0000-000000000001', '35000000-0000-0000-0000-000000000001',
   'Actividad', 'actividad', 70, 1),
  ('45000000-0000-0000-0000-000000000002', '35000000-0000-0000-0000-000000000001',
   'Quiz', 'quiz', 30, 2),
  ('45000000-0000-0000-0000-000000000003', '35000000-0000-0000-0000-000000000002',
   'Actividad', 'actividad', 70, 1),
  ('45000000-0000-0000-0000-000000000004', '35000000-0000-0000-0000-000000000002',
   'Quiz', 'quiz', 30, 2),
  ('45000000-0000-0000-0000-000000000005', '35000000-0000-0000-0000-000000000003',
   'Actividad', 'actividad', 100, 1),
  ('45000000-0000-0000-0000-000000000006', '35000000-0000-0000-0000-000000000004',
   'Examen', 'examen', 100, 1);

-- ---------------------------------------------------------------------------
-- LA prueba de los dos niveles
--
-- Una Actividad de 5.0 en la Unidad 1 aporta 30% × 70% = 21% de la definitiva, no el 70%.
-- Si alguien aplanara los pesos al guardarlos, esto daría 3.5 en vez de 1.05.
-- ---------------------------------------------------------------------------

insert into notas (item_id, inscripcion_id, valor, registrada_por)
values ('45000000-0000-0000-0000-000000000001', '25000000-0000-0000-0000-000000000001', 5.0,
        'b5b5b5b5-0000-0000-0000-000000000001');

select is(
  public.calcular_definitiva('25000000-0000-0000-0000-000000000001'),
  1.05,
  'Una Actividad de 5.0 en la Unidad 1 aporta 1.05 — el 21% de la escala, no el 70%'
);

select is(
  (select definitiva from inscripciones where id = '25000000-0000-0000-0000-000000000001'),
  1.0500,
  'El disparador mantiene inscripciones.definitiva al día'
);

-- ---------------------------------------------------------------------------
-- Curso completo: si todo es 5.0, la definitiva es exactamente 5.0.
-- Es la comprobación de que los pesos cierran.
-- ---------------------------------------------------------------------------

-- Acotado al curso de esta prueba. Sin el join contra componentes_evaluacion, esto
-- recogeria tambien los items de la semilla y la definitiva saldria de otro planeta: una
-- prueba que asume la base vacia se rompe el dia que existe supabase/seed.sql.
insert into notas (item_id, inscripcion_id, valor, registrada_por)
select i.id, '25000000-0000-0000-0000-000000000001', 5.0,
       'b5b5b5b5-0000-0000-0000-000000000001'
from items_calificables i
join componentes_evaluacion c on c.id = i.componente_id
where c.curso_id = '15000000-0000-0000-0000-000000000001'
  and i.id <> '45000000-0000-0000-0000-000000000001';

select is(
  public.calcular_definitiva('25000000-0000-0000-0000-000000000001'),
  5.00,
  'Todos los ítems en 5.0 dan una definitiva de exactamente 5.0'
);

-- ---------------------------------------------------------------------------
-- Precisión: el caso que la coma flotante arruina (adr/0004).
--
-- Unidad 1 = 4.0, Unidad 2 = 4.0, Unidad 3 = 4.0, Examen Final = 3.0
--   → 1.20 + 1.20 + 1.00 + 0.45 = 3.85 exacto
--
-- En `double precision` ese 3.85 se almacena como 3.8499… y se redondea a 3.8: el
-- estudiante pierde una décima y, con un umbral de por medio, a veces la materia.
-- ---------------------------------------------------------------------------

update notas set valor = 4.0
where inscripcion_id = '25000000-0000-0000-0000-000000000001';

update notas set valor = 3.0
where inscripcion_id = '25000000-0000-0000-0000-000000000001'
  and item_id = '45000000-0000-0000-0000-000000000006';

select is(
  public.calcular_definitiva('25000000-0000-0000-0000-000000000001'),
  3.85,
  'La definitiva es exactamente 3.85, sin arrastre de coma flotante'
);

select is(
  round(public.calcular_definitiva('25000000-0000-0000-0000-000000000001'), 1),
  3.9,
  'Redondear 3.85 a un decimal da 3.9, no 3.8'
);

-- ---------------------------------------------------------------------------
-- El tipo de dato no admite basura
-- ---------------------------------------------------------------------------

select throws_ok(
  $$insert into notas (item_id, inscripcion_id, valor, registrada_por)
    values ('45000000-0000-0000-0000-000000000001',
            '25000000-0000-0000-0000-000000000001', 5.5,
            'b5b5b5b5-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'Una nota de 5.5 se rechaza: la escala llega hasta 5.0'
);

select throws_ok(
  $$insert into notas (item_id, inscripcion_id, valor, registrada_por)
    values ('45000000-0000-0000-0000-000000000002',
            '25000000-0000-0000-0000-000000000001', 0.9,
            'b5b5b5b5-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'Una nota de 0.9 se rechaza: el piso de la escala es 1.0'
);

-- ---------------------------------------------------------------------------
-- Habilitación: tope de 3.0 y la definitiva original intacta
-- ---------------------------------------------------------------------------

-- Se lleva la definitiva a la banda 2.0–2.9.
update notas set valor = 2.5
where inscripcion_id = '25000000-0000-0000-0000-000000000001';

insert into habilitaciones (
  inscripcion_id, definitiva_original, nota_habilitacion, tope_aplicado, estado, autorizada_por
)
values (
  '25000000-0000-0000-0000-000000000001',
  (select definitiva from inscripciones where id = '25000000-0000-0000-0000-000000000001'),
  4.5, 3.0, 'presentada', 'c5c5c5c5-0000-0000-0000-000000000001'
);

select is(
  (select nota_final from habilitaciones
   where inscripcion_id = '25000000-0000-0000-0000-000000000001'),
  3.0,
  'Una habilitación de 4.5 da nota_final 3.0 por el tope'
);

select is(
  (select definitiva from inscripciones where id = '25000000-0000-0000-0000-000000000001'),
  2.5000,
  'inscripciones.definitiva NO se sobrescribió: la original sigue ahí'
);

select is(
  (select nota_efectiva from v_nota_efectiva
   where inscripcion_id = '25000000-0000-0000-0000-000000000001'),
  3.0,
  'La vista resuelve la nota vigente como la resultante de la habilitación'
);

-- Presentar la recuperación nunca puede dejar al estudiante peor: se conserva la más alta.
update habilitaciones set nota_habilitacion = 1.5
where inscripcion_id = '25000000-0000-0000-0000-000000000001';

select is(
  (select nota_final from habilitaciones
   where inscripcion_id = '25000000-0000-0000-0000-000000000001'),
  2.5,
  'Una habilitación PEOR que la original conserva la original: se queda la más alta'
);

-- ---------------------------------------------------------------------------
-- Abrir el curso valida la estructura
-- ---------------------------------------------------------------------------

select lives_ok(
  $$update cursos set estado = 'abierto'
    where id = '15000000-0000-0000-0000-000000000001'$$,
  'Un curso con la estructura completa se puede abrir'
);

insert into cursos (id, cohorte_id, materia_id, docente_id, periodo_orden, estado)
values ('15000000-0000-0000-0000-000000000002', 'e5000000-0000-0000-0000-000000000001',
        'd5000000-0000-0000-0000-000000000002', 'b5b5b5b5-0000-0000-0000-000000000001',
        1, 'borrador');

insert into componentes_evaluacion (id, curso_id, corte, nombre, tipo, peso)
values ('35000000-0000-0000-0000-000000000005', '15000000-0000-0000-0000-000000000002', 1,
        'Unidad única', 'unidad', 80);

select throws_ok(
  $$update cursos set estado = 'abierto'
    where id = '15000000-0000-0000-0000-000000000002'$$,
  '23514',
  null,
  'No se puede abrir un curso cuyos componentes no suman 100'
);

update componentes_evaluacion set peso = 100
where id = '35000000-0000-0000-0000-000000000005';

insert into items_calificables (componente_id, nombre, tipo, peso)
values ('35000000-0000-0000-0000-000000000005', 'Actividad', 'actividad', 60);

select throws_ok(
  $$update cursos set estado = 'abierto'
    where id = '15000000-0000-0000-0000-000000000002'$$,
  '23514',
  null,
  'No se puede abrir un curso cuyos ítems no suman 100 dentro del componente'
);

-- ---------------------------------------------------------------------------
-- El docente captura notas; no toca la estructura ni escribe con el curso cerrado
-- ---------------------------------------------------------------------------

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"b5b5b5b5-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- Ojo con la forma de esta comprobación: un UPDATE que la RLS filtra por `using` NO lanza
-- error, simplemente afecta a cero filas. Solo el `with check` lanza 42501. Comprobar que
-- "lanza" sería comprobar algo que no ocurre, y la prueba pasaría por el motivo equivocado.
update componentes_evaluacion set peso = 50
where id = '35000000-0000-0000-0000-000000000001';

select is(
  (select peso from componentes_evaluacion
   where id = '35000000-0000-0000-0000-000000000001'),
  30.00,
  'El docente NO puede cambiar los pesos: su UPDATE no toca ninguna fila'
);

-- Al cerrar el periodo, el docente deja de poder escribir. Es lo que hace que el boletín
-- emitido siga coincidiendo con la base de datos (plan.md 5.2).
select set_config(
  'request.jwt.claims',
  '{"sub":"c5c5c5c5-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

update cursos set estado = 'cerrado' where id = '15000000-0000-0000-0000-000000000001';

-- Coordinación deja un ítem sin calificar para poder probar la inserción más abajo.
insert into items_calificables (id, componente_id, nombre, tipo, peso)
values ('45000000-0000-0000-0000-000000000009', '35000000-0000-0000-0000-000000000003',
        'Actividad tardía', 'actividad', 10);

select set_config(
  'request.jwt.claims',
  '{"sub":"b5b5b5b5-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);

-- Modificar una nota existente: la fila deja de ser visible para escritura y el UPDATE
-- afecta a cero filas.
update notas set valor = 5.0
where item_id = '45000000-0000-0000-0000-000000000001'
  and inscripcion_id = '25000000-0000-0000-0000-000000000001';

select is(
  (select valor from notas
   where item_id = '45000000-0000-0000-0000-000000000001'
     and inscripcion_id = '25000000-0000-0000-0000-000000000001'),
  2.5,
  'Con el curso cerrado, el UPDATE del docente no cambia la nota'
);

-- Insertar una nota nueva sí lanza: ahí quien decide es el `with check`, y un `with check`
-- que no se cumple es un error, no un silencio.
select throws_ok(
  $$insert into notas (item_id, inscripcion_id, valor, registrada_por)
    values ('45000000-0000-0000-0000-000000000009',
            '25000000-0000-0000-0000-000000000001', 4.0,
            'b5b5b5b5-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'Con el curso cerrado, el docente NO puede registrar una nota nueva'
);

select * from finish();

rollback;
