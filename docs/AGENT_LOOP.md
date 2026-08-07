# Protocolo de trabajo iterativo con Claude Code

## Loop vs. agent loop

- Un **loop** repite una acción hasta que se cumple una condición. No razona.
- Un **agent loop** es: planear → ejecutar → **observar el resultado** → corregir → repetir.
  La diferencia está en la observación: el agente comprueba si lo que hizo funcionó y
  reacciona en consecuencia.

Un agent loop solo funciona si existen tres cosas. Si falta una, el agente no itera: adivina.

1. **Un criterio de salida que una máquina pueda evaluar.** "Está bien" no sirve.
   `npm run verify` en verde, sí.
2. **Estado que sobreviva entre sesiones.** El contexto se pierde; un archivo en el repo no.
3. **Compuertas humanas donde el error es caro.** Autonomía dentro de una tarea, revisión
   entre tareas.

---

## El comando que sostiene todo

```json
{
  "scripts": {
    "verify": "npm run lint && npm run typecheck && npm run test && npm run test:rls && npm run test:budget"
  }
}
```

`verify` es el corazón del protocolo. **Si no hay un comando que responda verde o rojo, no hay
agent loop posible.** Debe existir desde el encargo 01, aunque al principio casi no pruebe nada.

Qué cubre, en orden de rapidez:

| Chequeo | Qué protege |
|---|---|
| `lint` + `typecheck` | Errores triviales antes de gastar tiempo en pruebas |
| `test` | Lógica de dominio, sobre todo el cálculo de notas de dos niveles |
| `test:rls` | Aislamiento entre estudiantes y entre docentes. **No negociable** |
| `test:budget` | Bundle < 180 KB gzip y presupuesto de Lighthouse |

---

## Los tres bucles

### Bucle 1 — Dentro de una tarea (autónomo)

El agente lo ejecuta sin pedir permiso en cada vuelta:

```
1. Leer CLAUDE.md, docs/PROGRESO.md y el encargo activo
2. Escribir el plan de la rebanada más pequeña que se pueda verificar
3. Implementar solo esa rebanada
4. Ejecutar `npm run verify`
5. ¿Rojo?  → diagnosticar y corregir. Máximo 3 intentos.
             Al cuarto, DETENERSE y reportar hipótesis, sin seguir tocando código.
   ¿Verde? → commit con mensaje descriptivo
6. Actualizar docs/PROGRESO.md
7. ¿Queda alcance en el encargo? → volver al paso 2
   ¿Terminó? → reportar y esperar revisión humana
```

La regla de los tres intentos existe porque un agente atascado no se atasca en silencio:
empieza a cambiar cosas cada vez más lejanas al problema. Tres intentos y parada.

### Bucle 2 — Entre tareas (con compuerta humana)

Al terminar un encargo, **tú revisas antes de que empiece el siguiente**. Qué mirar:

- El diff completo, no el resumen del agente.
- ¿Se cumplió el criterio de aceptación del encargo, literalmente?
- ¿Aparecieron archivos o dependencias que nadie pidió?
- ¿Se tocó algo fuera del alcance declarado?

### Bucle 3 — Al cerrar una fase

Revisión más profunda: esquema completo, políticas RLS leídas una por una, y rendimiento
medido en un dispositivo real, no en el simulador.

---

## Condiciones de parada obligatorias

El agente **debe detenerse y preguntar** cuando:

1. Necesita un valor de negocio que no está en `docs/` → ver `PENDIENTES.md`.
2. Lleva 3 intentos fallidos en `verify`.
3. El cambio implica **modificar una migración ya aplicada**. Las migraciones se corrigen con
   una migración nueva, nunca editando la anterior.
4. Aparece la tentación de **desactivar RLS o usar la `service_role` key** para resolver un
   error de permisos. Esto es siempre una política mal escrita, nunca una excepción legítima.
5. El cambio excede el alcance del encargo, o toca más módulos de los previstos.
6. Se contradice un ADR. Cambiar un ADR es una decisión humana: se escribe uno nuevo que lo
   supersede, no se ignora el existente.

---

## Estado entre sesiones

`docs/PROGRESO.md` es la memoria del proyecto. El agente lo lee al empezar cada sesión y lo
actualiza al terminar cada tarea. Sin él, cada sesión nueva empieza a ciegas y repite trabajo.

---

## Prompt de arranque de sesión

Para pegar al abrir Claude Code:

```
Lee CLAUDE.md, docs/PROGRESO.md y docs/AGENT_LOOP.md.

Tarea de esta sesión: docs/encargos/NN-nombre.md

Trabaja según el Bucle 1 de AGENT_LOOP.md: rebanadas pequeñas, `npm run verify`
en verde antes de cada commit, y actualiza docs/PROGRESO.md al cerrar cada paso.

Detente y pregúntame si se cumple cualquier condición de parada. No inventes
valores de negocio: si falta uno, está en docs/PENDIENTES.md y me lo consultas.

Empieza mostrándome tu plan antes de escribir código.
```

## Prompt de cierre de sesión

```
Actualiza docs/PROGRESO.md con lo hecho, lo que quedó pendiente y cualquier
decisión que hayas tomado y que yo deba confirmar. Lista los archivos tocados.
```
