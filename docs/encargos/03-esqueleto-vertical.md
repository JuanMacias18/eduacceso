# Encargo 03 — Esqueleto vertical

**Objetivo:** una rebanada delgada que atraviesa todas las capas. Un estudiante real inicia
sesión desde un celular, ve un curso con un video y una nota. Una sola materia.

No construir a lo ancho: la meta es demostrar que el camino completo funciona antes de
invertir en superficie.

## Alcance

1. **Autenticación mixta** (ver `docs/adr/0003`):
   - Estudiante: documento + contraseña, con correo sintético interno.
   - Docente / coordinador: correo + contraseña.
   - Cambio de contraseña obligatorio en el primer ingreso.
2. Rutas protegidas por rol, con carga diferida: el estudiante no descarga el código del panel
   administrativo.
3. **Función RPC `dashboard_estudiante()`** (sección 9 del modelo de datos), consumida en una
   sola llamada.
4. Pantalla de dashboard del estudiante: sus materias del periodo activo.
5. Pantalla de curso: módulos, un recurso de video y una nota publicada.
6. **Reproductor de YouTube con fachada**: miniatura estática, `iframe` montado solo al hacer
   clic, dominio `youtube-nocookie.com`.
7. Diseño mobile-first. Se prueba en un viewport de 360 px de ancho antes que en escritorio.

## Restricciones

- Máximo 3 consultas a la base por carga de pantalla.
- Bundle inicial < 180 KB gzip.
- Sin librería de componentes pesada: Tailwind y componentes propios.

## Criterio de aceptación

- Con la red simulada en 3G lenta, el dashboard alcanza LCP < 2.5 s.
- Un estudiante de la semilla inicia sesión, ve su materia, reproduce el video y ve su nota.
- Otro estudiante no puede acceder a nada de él, y eso lo demuestra `test:rls` en verde.
- Lighthouse CI corriendo sobre el dashboard, con presupuesto de rendimiento activo en CI.
