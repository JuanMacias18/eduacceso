-- Semilla de desarrollo — DATOS FICTICIOS
--
-- CLAUDE.md regla 19: los datos de prueba son anonimizados. Nunca se copia produccion a un
-- entorno de pruebas con nombres y documentos reales — eso convierte el entorno de pruebas
-- en un problema de proteccion de datos, y aqui hay menores de por medio.
--
-- Todo lo que sigue esta inventado: las personas no existen, los documentos son correlativos
-- y los identificadores de YouTube son marcadores. Cuando se suban los videos reales deben
-- quedar como NO LISTADOS: los privados no se pueden incrustar y romperian la vista de curso
-- (ver PENDIENTES.md).
--
-- La contrasena de todas las cuentas sembradas es 'eduacceso-local'. Es una credencial de
-- desarrollo para una base que vive en tu portatil y se recrea con `supabase db reset`.

-- ---------------------------------------------------------------------------
-- Catalogo: 2 programas con sus periodos (adr/0005)
-- ---------------------------------------------------------------------------

insert into programas (id, codigo, nombre, tipo, nota_minima_aprobatoria) values
  ('10000000-0000-0000-0000-000000000001', 'TEC-SOL',
   'Tecnico Laboral en Soldadura y Oxicorte', 'tecnico', 3.0),
  ('10000000-0000-0000-0000-000000000002', 'BACH-ACE',
   'Bachillerato Acelerado', 'bachillerato', 3.0);

-- Tecnicos: 3 cuatrimestres de 4 meses. Bachillerato: 2 periodos de 6 meses.
insert into periodos_programa (programa_id, orden, etiqueta, duracion_meses) values
  ('10000000-0000-0000-0000-000000000001', 1, 'Cuatrimestre 1', 4),
  ('10000000-0000-0000-0000-000000000001', 2, 'Cuatrimestre 2', 4),
  ('10000000-0000-0000-0000-000000000001', 3, 'Cuatrimestre 3', 4),
  ('10000000-0000-0000-0000-000000000002', 1, 'Periodo 1 · Grado 10', 6),
  ('10000000-0000-0000-0000-000000000002', 2, 'Periodo 2 · Grado 11', 6);

-- Las materias del tecnico se dictan en secuencia: 5 de 3 semanas por cuatrimestre.
insert into materias (id, programa_id, periodo_orden, codigo, nombre, orden, intensidad_horaria) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 1,
   'SOL-101', 'Materiales y Metalurgia Basica', 1, 60),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 1,
   'SOL-102', 'Seguridad Industrial y Salud Ocupacional', 2, 60),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 1,
   'SOL-103', 'Interpretacion de Planos', 3, 60),
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 1,
   'SOL-104', 'Soldadura SMAW Basica', 4, 60),
  ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 1,
   'SOL-105', 'Oxicorte y Preparacion de Juntas', 5, 60),
  ('20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001', 2,
   'SOL-201', 'Soldadura GMAW', 1, 60),
  ('20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000001', 2,
   'SOL-202', 'Inspeccion Visual de Soldadura', 2, 60),
  ('20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000002', 1,
   'BA-101', 'Matematicas I', 1, 120),
  ('20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000002', 1,
   'BA-102', 'Lengua Castellana I', 2, 120),
  ('20000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000002', 1,
   'BA-103', 'Ciencias Naturales I', 3, 120);

insert into cohortes (id, programa_id, nombre, municipio, departamento, fecha_inicio,
                      periodo_actual, estado) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'Puerto Lopez 2026-1', 'Puerto Lopez', 'Meta', date '2026-02-02', 1, 'activa');

-- ---------------------------------------------------------------------------
-- Personas — todas inventadas
--
-- Estudiantes: documento + contrasena, con correo sintetico interno (adr/0003). El correo
-- sintetico no debe parecer real ni usarse para enviar nada: de ahi el dominio .local.
-- Docentes y coordinacion: correo + contrasena.
-- ---------------------------------------------------------------------------

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_user_meta_data)
select
  v.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  v.correo, extensions.crypt('eduacceso-local', extensions.gen_salt('bf')),
  now(), '{"sembrado": true}'::jsonb
from (values
  ('40000000-0000-0000-0000-000000000001'::uuid, '1010000001@estudiantes.eduacceso.local'),
  ('40000000-0000-0000-0000-000000000002'::uuid, '1010000002@estudiantes.eduacceso.local'),
  ('40000000-0000-0000-0000-000000000003'::uuid, '1010000003@estudiantes.eduacceso.local'),
  ('40000000-0000-0000-0000-000000000004'::uuid, '1010000004@estudiantes.eduacceso.local'),
  ('40000000-0000-0000-0000-000000000005'::uuid, '1010000005@estudiantes.eduacceso.local'),
  ('40000000-0000-0000-0000-000000000006'::uuid, '1010000006@estudiantes.eduacceso.local'),
  ('40000000-0000-0000-0000-000000000007'::uuid, '1010000007@estudiantes.eduacceso.local'),
  ('40000000-0000-0000-0000-000000000008'::uuid, '1010000008@estudiantes.eduacceso.local'),
  ('50000000-0000-0000-0000-000000000001'::uuid, 'docente.uno@eduacceso.local'),
  ('50000000-0000-0000-0000-000000000002'::uuid, 'docente.dos@eduacceso.local'),
  ('60000000-0000-0000-0000-000000000001'::uuid, 'coordinacion@eduacceso.local')
) as v(id, correo);

insert into perfiles (id, tipo_documento, numero_documento, nombres, apellidos,
                      fecha_nacimiento, telefono, correo) values
  ('40000000-0000-0000-0000-000000000001', 'CC', '1010000001', 'Yeimy Andrea', 'Roa Pineda', date '2002-04-11', '3210000001', null),
  ('40000000-0000-0000-0000-000000000002', 'CC', '1010000002', 'Brayan Steven', 'Cortes Mora', date '2001-09-23', '3210000002', null),
  ('40000000-0000-0000-0000-000000000003', 'TI', '1010000003', 'Luisa Fernanda', 'Barrera Gil', date '2009-01-30', '3210000003', null),
  ('40000000-0000-0000-0000-000000000004', 'CC', '1010000004', 'Jhon Freddy', 'Salgado Ruiz', date '1998-07-05', '3210000004', null),
  ('40000000-0000-0000-0000-000000000005', 'CC', '1010000005', 'Maryuri', 'Ospina Cardona', date '2000-12-14', '3210000005', null),
  ('40000000-0000-0000-0000-000000000006', 'TI', '1010000006', 'Kevin Alexis', 'Duarte Pena', date '2009-06-02', '3210000006', null),
  ('40000000-0000-0000-0000-000000000007', 'CC', '1010000007', 'Nury Milena', 'Cifuentes Avila', date '1997-03-19', '3210000007', null),
  ('40000000-0000-0000-0000-000000000008', 'CE', '1010000008', 'Deiby Santiago', 'Parrado Leon', date '2003-11-08', '3210000008', null),
  ('50000000-0000-0000-0000-000000000001', 'CC', '2020000001', 'Marta Lucia', 'Vega Cardenas', date '1985-05-21', '3220000001', 'docente.uno@eduacceso.local'),
  ('50000000-0000-0000-0000-000000000002', 'CC', '2020000002', 'Hernan Dario', 'Quintero Rojas', date '1979-10-02', '3220000002', 'docente.dos@eduacceso.local'),
  ('60000000-0000-0000-0000-000000000001', 'CC', '3030000001', 'Claudia Patricia', 'Nieto Saenz', date '1982-08-16', '3230000001', 'coordinacion@eduacceso.local');

insert into usuario_roles (usuario_id, rol)
select id, 'estudiante'::rol_usuario from perfiles where id::text like '40000000%'
union all select id, 'docente'::rol_usuario from perfiles where id::text like '50000000%'
union all select id, 'coordinador'::rol_usuario from perfiles where id::text like '60000000%';

-- Ley 1581: los dos menores de la cohorte llevan autorizacion del representante legal.
insert into autorizaciones_datos (titular_id, version_politica, es_menor,
                                  acudiente_nombre, acudiente_documento) values
  ('40000000-0000-0000-0000-000000000003', 'v1-2026-01', true,
   'Gloria Esperanza Gil de Barrera', '41000003'),
  ('40000000-0000-0000-0000-000000000006', 'v1-2026-01', true,
   'Alvaro Duarte Sanabria', '41000006');

insert into autorizaciones_datos (titular_id, version_politica, es_menor)
select id, 'v1-2026-01', false from perfiles
where id::text like '40000000%'
  and id not in ('40000000-0000-0000-0000-000000000003',
                 '40000000-0000-0000-0000-000000000006');

-- ---------------------------------------------------------------------------
-- Matricula, cursos e inscripcion
-- ---------------------------------------------------------------------------

insert into matriculas (id, estudiante_id, cohorte_id, codigo, fecha_matricula)
select
  ('70000000-0000-0000-0000-00000000000' || right(p.id::text, 1))::uuid,
  p.id,
  '30000000-0000-0000-0000-000000000001',
  'PL2026-' || lpad(right(p.id::text, 1), 3, '0'),
  date '2026-01-20'
from perfiles p where p.id::text like '40000000%';

-- Los cinco cursos del cuatrimestre 1, en secuencia. Nacen en borrador: al abrirlos se les
-- aplica la plantilla de evaluacion (ver 0006 y 0007).
insert into cursos (id, cohorte_id, materia_id, docente_id, periodo_orden, estado,
                    inicia_el, termina_el) values
  ('80000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 1,
   'borrador', date '2026-02-02', date '2026-02-20'),
  ('80000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002', 1,
   'borrador', date '2026-02-23', date '2026-03-13'),
  ('80000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000001', 1,
   'borrador', date '2026-03-16', date '2026-04-03'),
  ('80000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000002', 1,
   'borrador', date '2026-04-06', date '2026-04-24'),
  ('80000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000005', '50000000-0000-0000-0000-000000000001', 1,
   'borrador', date '2026-04-27', date '2026-05-15');

-- La primera materia esta en curso. El resto espera su turno: las materias del tecnico se
-- dictan en secuencia, no en paralelo.
update cursos set estado = 'abierto', abierto_en = now()
where id = '80000000-0000-0000-0000-000000000001';

insert into inscripciones (id, curso_id, matricula_id, estudiante_id)
select
  ('90000000-0000-0000-0000-00000000000' || right(m.estudiante_id::text, 1))::uuid,
  '80000000-0000-0000-0000-000000000001',
  m.id,
  m.estudiante_id
from matriculas m;

-- ---------------------------------------------------------------------------
-- Contenido del curso abierto
--
-- Los identificadores de YouTube son marcadores. Al subir los videos reales deben quedar
-- como NO LISTADOS: los privados no se pueden incrustar.
-- ---------------------------------------------------------------------------

insert into modulos (id, curso_id, titulo, descripcion, orden, publicado, publicado_en) values
  ('a0000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001',
   'Unidad 1 · Estructura de los metales', 'Que es un metal y por que se comporta asi.',
   1, true, now()),
  ('a0000000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000001',
   'Unidad 2 · Aleaciones y tratamientos', 'Aceros al carbono e inoxidables.', 2, true, now()),
  ('a0000000-0000-0000-0000-000000000003', '80000000-0000-0000-0000-000000000001',
   'Unidad 3 · Ensayos de materiales', 'Aun en preparacion.', 3, false, null);

insert into recursos (id, modulo_id, tipo, titulo, youtube_id, url, duracion_seg,
                      orden, publicado) values
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
   'video_youtube', 'Clase 1 · Estructura cristalina', 'VIDEO-FICTICIO-001', null, 840, 1, true),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001',
   'video_youtube', 'Clase 2 · Propiedades mecanicas', 'VIDEO-FICTICIO-002', null, 1020, 2, true),
  ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001',
   'enlace', 'Taller de la Unidad 1', null, 'https://ejemplo.local/taller-unidad-1', null, 3, true),
  ('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000002',
   'video_youtube', 'Clase 3 · Aceros al carbono', 'VIDEO-FICTICIO-003', null, 960, 1, true);

insert into anuncios (curso_id, titulo, cuerpo, autor_id) values
  ('80000000-0000-0000-0000-000000000001',
   'Entrega del taller de la Unidad 1',
   'El taller se entrega por el enlace publicado, hasta el domingo a las 11:59 p.m.',
   '50000000-0000-0000-0000-000000000001');

-- ---------------------------------------------------------------------------
-- Notas del primer corte, publicadas
--
-- Solo la Unidad 1: el resto del curso esta por delante, que es justo el estado en el que
-- se va a ver la plataforma durante el piloto.
--
-- Los valores son deterministas, no aleatorios: una semilla que cambia en cada reset hace
-- imposible razonar sobre lo que se ve en pantalla.
-- ---------------------------------------------------------------------------

insert into notas (item_id, inscripcion_id, valor, publicada, publicada_en, registrada_por)
select
  i.id,
  ins.id,
  (array[4.5, 3.8, 2.6, 4.0, 3.2, 2.9, 4.7, 3.5])[
    (right(ins.estudiante_id::text, 1))::int
  ]::numeric(2,1),
  true,
  now(),
  '50000000-0000-0000-0000-000000000001'
from inscripciones ins
join componentes_evaluacion c on c.curso_id = ins.curso_id and c.nombre = 'Unidad 1'
join items_calificables i on i.componente_id = c.id
where ins.curso_id = '80000000-0000-0000-0000-000000000001';

insert into progreso_recurso (estudiante_id, recurso_id)
select ins.estudiante_id, 'b0000000-0000-0000-0000-000000000001'
from inscripciones ins where ins.curso_id = '80000000-0000-0000-0000-000000000001';
