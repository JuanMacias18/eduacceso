# ADR 0008 — Tailwind CSS v4, sin patrones de v3

**Estado:** Aceptada · agosto 2026

## Contexto

El encargo 01 tenía que elegir versión de Tailwind. Las dos son defendibles, pero mezclarlas
no: aplicar patrones de v3 sobre una instalación de v4 **no rompe el build, rompe los estilos
en silencio**. Un `@tailwind base` que ya no hace nada, un `bg-opacity-50` que se ignora, un
`tailwind.config.js` que nadie lee. El síntoma aparece semanas después como "esta pantalla se
ve rara" y cuesta mucho rastrear.

Estado real del ecosistema en el momento de decidir, comprobado contra el registro de npm y la
documentación vigente, no de memoria:

| Dato | Valor |
|---|---|
| `tailwindcss@latest` | 4.3.3 |
| Etiqueta de la línea 3 | `v3-lts` → 3.4.19 (mantenimiento) |
| `@tailwindcss/vite` | 4.3.3 |
| Vite del proyecto | 8.2.1 |

## Decisión

**Tailwind v4**, integrado con `@tailwindcss/vite`.

Tres razones, en orden de peso:

1. **La v3 ya está en mantenimiento.** Su propia etiqueta en npm es `v3-lts`. Este proyecto se
   presupuesta en 12–16 semanas y luego se opera durante años con un solo desarrollador
   (`plan.md`, atributo de calidad 3). Empezar sobre la rama que solo recibe parches es elegir
   una migración futura a cambio de nada hoy.
2. **La v4 tiene menos piezas.** Desaparecen `tailwind.config.js`, `postcss.config.js` y
   `autoprefixer`. Tres archivos menos que mantener y tres menos que configurar mal.
3. **El riesgo que la v3 evitaba se puede automatizar.** "Acuérdate de no mezclar" no es un
   control; un script que falla el lint sí lo es. Ver más abajo.

## Cómo se escribe aquí

| Aspecto | En este proyecto |
|---|---|
| Entrada | `@import 'tailwindcss'` en `src/index.css` |
| Configuración | CSS-first, con `@theme` en `src/index.css` |
| Utilidades propias | directiva `@utility`, no `@layer utilities` |
| Valores del tema | `var(--color-...)`, no la función `theme()` |
| Opacidad | `bg-sky-500/50`, no `bg-opacity-50` |
| Crecer/encoger | `grow-*` y `shrink-*`, no `flex-grow-*` |
| Detección de contenido | acotada a `src/` con `source('../src')` |

**Dos trampas que no se detectan solas** y hay que tener presentes al copiar código de
internet, porque casi todo lo que se encuentra está escrito para v3:

- `rounded` de v3 es `rounded-sm` en v4, y `rounded-sm` de v3 es `rounded-xs`.
- `shadow-sm` de v3 es `shadow-xs` en v4, y toda la escala de sombras está corrida un paso.

Existen en las dos versiones con significados distintos, así que ningún script puede
distinguirlas. Se resuelven leyendo, no automatizando.

Además, el color de borde por defecto cambió de `gray-200` a `currentColor`.

## El control automático

`scripts/verificar-tailwind-v4.mjs` cuelga de `npm run lint`, y por tanto de
`npm run verify`. Falla si encuentra:

- las directivas `@tailwind base|components|utilities`;
- un `tailwind.config.*` o un `postcss.config.*`;
- `autoprefixer` o `postcss` como dependencias directas;
- la función `theme()` o `@layer utilities` en una hoja de estilos;
- clases retiradas: `*-opacity-*`, `flex-grow`, `flex-shrink`, `decoration-slice`,
  `decoration-clone`, `overflow-ellipsis`.

Y también al revés: falla si **desaparece** el `@import 'tailwindcss'` o si `vite.config.ts`
deja de registrar el plugin. Una migración a medias es tan mala como no migrar.

## Alternativa descartada

**Tailwind v3.4.19.** Terreno más pisado y toda la documentación de internet aplica sin
traducir. Se descarta porque la ventaja es temporal —hoy escribes menos, en un año migras— y
porque el riesgo que la justificaba (mezclar versiones) queda cubierto por el script.

## Consecuencias

- El código que se copie de tutoriales hay que traducirlo. Es el costo real de esta decisión.
- Un `postcss.config.js` añadido por reflejo rompe el lint con un mensaje que explica por qué.
- Si algún día se adopta la v5, este ADR se supersede con uno nuevo y el script se actualiza
  con las clases que esa versión retire. No se edita este.

## Nota de verificación

Las versiones y el procedimiento de instalación de esta decisión se comprobaron contra el
registro de npm y la documentación vigente de Tailwind durante el encargo 01. La instalación
se validó además en ejecución: el color de fondo computado en el navegador sale en `oklch`,
que es como la v4 emite su paleta — la v3 la emitía en hex/rgb.
