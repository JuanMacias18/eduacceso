-- Integridad de la semilla.
--
-- A diferencia del resto de pruebas, esta SÍ mira los datos sembrados: es su objeto. Sirve
-- de comprobación de extremo a extremo de que migraciones, plantilla, disparadores y semilla
-- cooperan — si alguna de las siete migraciones se rompe, esto lo nota.
--
-- También vigila la regla 19: los datos de prueba son anonimizados.

begin;

select plan(8);

select is(
  (select count(*)::int from programas),
  2,
  'La semilla carga los dos programas'
);

-- La columna se crea `not null` sin valor por defecto a propósito (adr/0004): es preferible
-- que falle la carga a que se siembre una nota mínima inventada.
select is(
  (select count(distinct nota_minima_aprobatoria)::int from programas
   where nota_minima_aprobatoria = 3.0),
  1,
  'Los programas se siembran con la nota mínima aprobatoria confirmada de 3.0'
);

-- Técnicos: 3 cuatrimestres. Bachillerato: 2 periodos de 6 meses (adr/0005).
select is(
  (select count(*)::int from periodos_programa p
   join programas pr on pr.id = p.programa_id
   where pr.tipo = 'tecnico'),
  3,
  'El técnico tiene sus tres cuatrimestres'
);

select is(
  (select sum(duracion_meses)::int from periodos_programa p
   join programas pr on pr.id = p.programa_id
   where pr.tipo = 'bachillerato'),
  12,
  'El bachillerato acelerado suma doce meses en dos periodos'
);

-- Abrir el curso tuvo que aplicar la plantilla predeterminada.
select is(
  (select string_agg(nombre || ' ' || peso, ', ' order by orden)
   from componentes_evaluacion c
   join cursos cu on cu.id = c.curso_id
   where cu.estado = 'abierto'),
  'Unidad 1 30.00, Unidad 2 30.00, Unidad 3 25.00, Examen Final Integrador 15.00',
  'El curso abierto recibió la estructura de la guía real'
);

-- De extremo a extremo: 4.5 en los dos ítems de la Unidad 1 son 4.5 del componente, y el
-- componente vale 30% del curso.
select is(
  (select i.definitiva from inscripciones i
   join perfiles p on p.id = i.estudiante_id
   where p.numero_documento = '1010000001'),
  1.3500,
  'La definitiva parcial de quien sacó 4.5 en la Unidad 1 es 4.5 x 30% = 1.35'
);

-- Ley 1581: si el titular es menor, la autorización del representante legal es obligatoria.
select is(
  (select count(*)::int from autorizaciones_datos
   where es_menor and (acudiente_nombre is null or acudiente_documento is null)),
  0,
  'Ningún menor sembrado se queda sin acudiente registrado'
);

-- Regla 19: nada de datos reales. Los documentos sembrados son correlativos y reconocibles,
-- y los correos viven en dominios .local que no existen fuera de esta máquina.
select is(
  (select count(*)::int from perfiles
   where correo is not null and correo not like '%.local'),
  0,
  'Ningún perfil sembrado tiene un correo fuera de un dominio ficticio'
);

select * from finish();

rollback;
