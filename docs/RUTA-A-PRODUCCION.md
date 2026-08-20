# Ruta a producción

> Qué falta para que EduAcceso pueda usar esto de verdad, qué hay que auditar antes de que
> entre un solo dato real, y en qué orden. Complementa a `PENDIENTES.md` (decisiones de
> negocio) y a `PROGRESO.md` (bitácora de lo hecho).
>
> **Última revisión:** 2026-08-19

## Dónde estamos, sin adornos

**No hay plataforma todavía.** El código de producto es una página en blanco y tres módulos
vacíos. Nadie puede iniciar sesión y no existe una sola pantalla.

Lo construido son los cimientos y el modelo de datos: 8 migraciones, 46 políticas RLS, 83
pruebas pgTAP y CI en verde. Es la parte cara de cambiar después —y la que evita migrar notas
reales dentro de un año— pero es **invisible para el cliente**.

Contra el cronograma del plan (12,5 semanas, presupuestadas como 16): hecha la fase 0 técnica
y la mitad de esquema de la fase 1. **Quedan las fases 1 a 6 casi enteras.**

| Fase | Estado |
|---|---|
| 0 · Cimientos técnicos | hecho (encargo 01) |
| 0 · Descubrimiento con el cliente | **no empezado** — ver "Lo que depende del cliente" |
| 1 · Esquema y RLS | hecho (encargo 02) |
| 1 · Esqueleto vertical | pendiente (encargo 03, escrito) |
| 2 · Catálogo y matrícula | **sin encargo escrito** |
| 3 · Portal del estudiante | **sin encargo escrito** |
| 4 · Evaluación y boletines | **sin encargo escrito** |
| 5 · Piloto controlado | **sin encargo escrito** |
| 6 · Endurecimiento y despliegue | **sin encargo escrito** |

Solo existen encargos hasta el 03: **la mitad del proyecto no tiene ni alcance definido.**

## Lo que depende del cliente y puede arrancar hoy

Nada de esto lo resuelve el desarrollo, y todo tiene plazos de terceros. Es lo que más riesgo
acumula por empezar tarde. El documento para pedirlo está en `peticion-a-coordinacion.md`.

| Qué | Quién responde | Por qué bloquea |
|---|---|---|
| **Política de tratamiento de datos** (P3) | Dirección + asesoría jurídica | Sin ella no se puede tocar un dato real de un menor. Requisito legal, no papeleo |
| **Pensum en CSV** | Coordinación | Es el insumo del importador. 250 materias no se digitan a mano |
| **Formato oficial del boletín** | Coordinación | El boletín generado debe coincidir con el que hoy se emite. Sin verlo se construye a ciegas |
| **Llevar un corte real en hoja de cálculo** | Coordinación | Cuesta cero y puede cambiar el plan: si no logran llenar una hoja a tiempo, el software no lo arregla — lo hace más visible |
| **Cuántos docentes y qué manejo tienen** (P2) | Dirección | Define el diseño de la planilla, la pantalla más usada del sistema |
| **Datos históricos a migrar** (P4) | Coordinación | Si los hay, es una fase adicional que hoy no está presupuestada |
| **Videos en modo "no listado"** | Quien administre el canal | Los privados **no se pueden incrustar** y romperían la vista de curso. Verificar con el primero que se suba, no con el último |

**P1** (recuperación para definitivas entre 1.0 y 1.9) no bloquea: está deliberadamente sin
implementar y el esquema admite añadirla sin migrar nada.

## Auditoría antes de que entre un dato real

Ordenada por lo que cuesta más caro pasar por alto.

### Puerta de una vía — decidir ANTES de crear el proyecto de producción

- **La región del proyecto Supabase no se cambia después.** Elegirla sabiendo que los datos
  salen de Colombia, y documentar esa transferencia internacional en la política de
  tratamiento (Ley 1581). Equivocarse aquí se paga migrando la base entera.

### Seguridad — el Bucle 3 del protocolo

- **Leer las 46 políticas RLS una por una** contra la matriz de acceso de
  `modelo-datos.md` §7. Las 83 pruebas cubren los caminos que se nos ocurrieron; no los que
  no se nos ocurrieron. Esta lectura no la sustituye ninguna prueba.
- **`auth.enable_signup` está en `true`**, que es el valor por defecto del CLI. Con identidad
  asignada por coordinación (`adr/0003`) tiene que ser `false`, o cualquiera se registra solo.
- **MFA obligatorio para `admin` y `coordinador`.** Decidido en el plan §5.1, sin implementar.
  Son las cuentas que pueden alterar notas de todos.
- **Rate limiting** en inicio de sesión y en recuperación de contraseña.
- **Cabeceras de seguridad en Vercel**: CSP, `X-Frame-Options`, `Referrer-Policy`.
- **Storage privado con URLs firmadas de vida corta.** Un boletín en un bucket público es una
  filtración esperando ocurrir.
- **La contraseña de la semilla (`eduacceso-local`) no puede llegar jamás a producción.** Hoy
  solo vive en `supabase/seed.sql`, que únicamente corre en local, pero conviene un control
  explícito antes del primer despliegue.
- **Escaneo de secretos en CI.** Ya está activo `secret scanning` con push protection en
  GitHub; verificar que sigue encendido tras cualquier cambio de visibilidad del repositorio.

### Operación — hoy no existe nada de esto

- **Respaldos restaurados de verdad en un proyecto limpio.** Un respaldo no probado no es un
  respaldo. Además de los diarios del plan de producción, un volcado lógico semanal a
  almacenamiento externo: siete días de retención es poco para registros académicos.
- **Alertas**: errores en producción, fallos masivos de autenticación, fallos en la generación
  de boletines.
- **Documento de operación** con el que otra persona pueda operar el sistema: cómo abrir un
  periodo, cómo matricular, cómo restaurar, qué hacer si el proveedor cae. Es la mitigación
  del riesgo "un solo desarrollador".
- **Revisión de índices con datos reales** y `pg_stat_statements`, no con la tabla vacía.

### Exposición pública del repositorio

El repositorio se hizo público el 2026-08-14 para poder proteger `main` sin plan de pago.
Antes se barrió la historia completa: cero credenciales y ningún dato personal.

Queda un punto abierto: **`PENDIENTES.md` P1** describe por escrito una deliberación
comercial pendiente de visto bueno jurídico, con menores de por medio, y hoy es legible por
cualquiera. Decidir si se reformula, se traslada a un documento interno, o el repositorio
vuelve a privado. **Pagar GitHub Pro más adelante no vuelve privado lo ya publicado.**

## Deuda técnica registrada

- **Playwright y `npm run test:e2e` no existen.** Llegan con el encargo 03, que es quien
  tiene pantallas que probar.
- **Lighthouse CI y el presupuesto de LCP tampoco.** Hoy `test:budget` mide solo el tamaño
  del bundle inicial (44,3 KB gzip de 180 permitidos). El LCP < 2,5 s en 3G necesita un
  dashboard que cargar, y **se mide en dispositivos reales en un municipio**, no en el
  simulador.
- **`contenido` ↔ `evaluacion` no está restringido entre sí.** Solo está prohibido que
  `academico` dependa de los otros dos, que es lo único que documenta `CLAUDE.md`.
- **Alcance del coordinador: organizacional completo.** Confirmado con dirección porque
  EduAcceso es un solo instituto. Revisar si aparece una segunda sede con coordinación propia.

## Orden sugerido

1. **Hoy**: enviar a coordinación las cuatro peticiones (`peticion-a-coordinacion.md`). Tienen
   plazos de terceros y todo lo demás puede avanzar en paralelo.
2. **Encargo 03** — esqueleto vertical. Es la primera vez que alguien podrá iniciar sesión y
   ver una nota. También es donde aparecen las sorpresas de integración.
3. **Escribir los encargos 04 en adelante** cuando el 03 esté cerrado, no antes: hasta
   entonces no sabemos si el modelo aguanta el uso real.
4. **Crear el proyecto Supabase de producción** con la región ya decidida, y el de pruebas.
5. **Auditoría de seguridad completa** antes de cargar la primera cohorte real.
