# ADR 0001 — Construir plataforma propia en lugar de adoptar un LMS

**Estado:** Aceptada · agosto 2026

## Contexto

EduAcceso necesita un portal donde ~200 estudiantes (creciendo a 500–800) consulten materias,
clases en video, material y notas. Los estudiantes están en municipios con conectividad móvil
limitada. El video ya vive en YouTube. Hay 20 programas técnicos de 3 cuatrimestres más
Bachillerato Acelerado, con ~250 materias en catálogo. El equipo de desarrollo es una persona.

## Opciones consideradas

1. **Moodle autohospedado** — maduro y completo, sin costo de licencia.
2. **Google Classroom** — costo cero si la institución califica ante Google.
3. **Plataforma propia** sobre React + Supabase + Vercel.

## Decisión

Construir plataforma propia, con alcance reducido en la v1 (sin tareas ni evaluaciones en
línea).

## Razones

- Lo que se necesita en la v1 es mayoritariamente **lectura**, no interacción. Un LMS completo
  es sobre-ingeniería para el problema real.
- El costo caro de un LMS (almacenamiento y transmisión de video) **no aplica**: YouTube ya lo
  resuelve.
- La estructura programa → periodo → materia y el **boletín en formato colombiano** son
  requisitos que ningún LMS genérico modela bien. En Moodle habría que exportar a Excel y
  armar los boletines aparte.
- La diferencia de costo de infraestructura entre Moodle y la opción propia es de USD 20–30
  al mes: irrelevante. La decisión no se tomó por dinero.

## Consecuencias

**Aceptamos:**
- Más tiempo hasta salir al aire (~12 semanas contra ~3 con Moodle).
- Dependencia de un solo desarrollador mientras no haya un segundo perfil.
- Sin tareas, quices ni foros en la v1.
- Sin ecosistema de plugins: todo lo que se necesite después hay que construirlo.

**Ganamos:**
- Modelo de datos alineado con la operación real.
- Boletines y certificados con formato e identidad propios.
- Control del rendimiento en redes lentas.

## Cuándo revisar esta decisión

Si se cumple alguna de estas condiciones, migrar a Moodle es la respuesta correcta:
evaluación calificada en línea obligatoria, más de ~1.000 estudiantes con equipos
administrativos independientes por sede, o imposibilidad de sostener desarrollo y soporte
durante 12 meses.
