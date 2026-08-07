# ADR 0003 — Identidad mixta: estudiantes por documento, docentes por correo

**Estado:** Aceptada · agosto 2026

## Contexto

Buena parte de los estudiantes está en municipios rurales y no tiene un correo electrónico que
revise con regularidad. Exigir correo para iniciar sesión genera soporte permanente y bloquea
el acceso el primer día. Los docentes, en cambio, sí tienen correo y ahora son responsables de
cargar las notas de sus cursos, lo que hace sus cuentas críticas y de uso frecuente.

## Decisión

- **Estudiantes:** ingresan con **número de documento + contraseña**. Internamente se genera un
  correo sintético para la cuenta de Auth. Contraseña temporal entregada en la matrícula, con
  cambio obligatorio en el primer ingreso. Si el estudiante registra un correo real, se le
  habilita recuperación automática.
- **Docentes, coordinadores y administradores:** ingresan con **correo + contraseña**, con
  recuperación estándar. **MFA obligatorio** para coordinación y administración.

## Consecuencias

**Aceptamos:**
- La recuperación de contraseña de un estudiante sin correo es **manual**: coordinación genera
  una temporal. Hay que nombrar a un responsable de esa tarea.
- El correo sintético no debe parecer real ni usarse para enviar nada.
- El documento pasa a ser identificador de acceso: hay que tratarlo con el mismo cuidado que
  cualquier dato personal y no exponerlo en URLs ni en logs.

**Ganamos:**
- Cero fricción de alta para el estudiante: todos saben su cédula.
- Las cuentas críticas (quienes escriben notas) quedan con el esquema más seguro.

## Revisar si

Se confirma que los estudiantes sí tienen y usan correo (ver P4 en `PENDIENTES.md`), o si el
volumen de restablecimientos manuales supera lo que coordinación puede atender.
