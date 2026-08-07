#!/usr/bin/env node
/**
 * Guardia de Tailwind v4.
 *
 * El proyecto está en Tailwind v4 (ver docs/adr/0008-tailwind-v4.md). Mezclar patrones de
 * v3 sobre una instalación de v4 no rompe el build: rompe los estilos en silencio, que es
 * mucho peor. Un `@tailwind base` que ya no hace nada, un `bg-opacity-50` que se ignora,
 * un `tailwind.config.js` que nadie lee.
 *
 * Este script convierte "acuérdate de no mezclar" en una comprobación que falla el lint.
 * Cuelga de `npm run lint`, y por tanto de `npm run verify`.
 *
 * No comprueba `shadow-*` ni `rounded-*`: existen en las dos versiones con significados
 * distintos y no se pueden distinguir mecánicamente. Eso está documentado en el ADR.
 */
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { exit } from 'node:process'

const raiz = process.cwd()
const problemas = []

const anotar = (archivo, mensaje) => {
  problemas.push({ archivo: archivo ? relative(raiz, archivo) : '—', mensaje })
}

const existe = (ruta) => {
  try {
    statSync(join(raiz, ruta))
    return true
  } catch {
    return false
  }
}

const leer = (ruta) => readFileSync(ruta, 'utf8')

/** Recorre un directorio devolviendo los archivos con las extensiones pedidas. */
const archivosCon = (dir, extensiones) => {
  const encontrados = []
  const recorrer = (actual) => {
    let entradas
    try {
      entradas = readdirSync(actual, { withFileTypes: true })
    } catch {
      return
    }
    for (const entrada of entradas) {
      const ruta = join(actual, entrada.name)
      if (entrada.isDirectory()) {
        if (entrada.name === 'node_modules' || entrada.name.startsWith('.')) continue
        recorrer(ruta)
      } else if (extensiones.some((ext) => entrada.name.endsWith(ext))) {
        encontrados.push(ruta)
      }
    }
  }
  recorrer(dir)
  return encontrados
}

// ---------------------------------------------------------------------------
// 1. Dependencias: v4 instalada, y sin el andamiaje de PostCSS que pedía la v3.
// ---------------------------------------------------------------------------
const paquete = JSON.parse(leer(join(raiz, 'package.json')))
const dependencias = { ...paquete.dependencies, ...paquete.devDependencies }

for (const nombre of ['tailwindcss', '@tailwindcss/vite']) {
  const rango = dependencias[nombre]
  if (!rango) {
    anotar('package.json', `falta la dependencia ${nombre}`)
  } else if (!/^[\^~]?4\./.test(rango)) {
    anotar('package.json', `${nombre} está en "${rango}"; se espera la línea 4.x`)
  }
}

for (const nombre of ['autoprefixer', 'postcss']) {
  if (dependencias[nombre]) {
    anotar(
      'package.json',
      `${nombre} es andamiaje de Tailwind v3. Con el plugin de Vite de v4 no hace falta; quítalo`,
    )
  }
}

// ---------------------------------------------------------------------------
// 2. Archivos de configuración que la v4 ya no usa.
// ---------------------------------------------------------------------------
for (const base of ['tailwind.config', 'postcss.config']) {
  for (const ext of ['.js', '.cjs', '.mjs', '.ts']) {
    if (existe(base + ext)) {
      anotar(
        base + ext,
        'Tailwind v4 se configura en CSS con @theme. Este archivo no se lee y da falsa sensación de estar configurando algo',
      )
    }
  }
}

// ---------------------------------------------------------------------------
// 3. vite.config.ts debe registrar el plugin de v4.
// ---------------------------------------------------------------------------
const viteConfig = join(raiz, 'vite.config.ts')
if (existe('vite.config.ts')) {
  const contenido = leer(viteConfig)
  if (!contenido.includes('@tailwindcss/vite')) {
    anotar(viteConfig, 'no importa @tailwindcss/vite: Tailwind no se estaría aplicando')
  }
  if (!/tailwindcss\(\)/.test(contenido)) {
    anotar(viteConfig, 'no registra tailwindcss() en la lista de plugins')
  }
} else {
  anotar('vite.config.ts', 'no existe')
}

// ---------------------------------------------------------------------------
// 4. CSS: debe existir el @import de v4, y no las directivas de v3.
// ---------------------------------------------------------------------------
const hojas = archivosCon(join(raiz, 'src'), ['.css'])
const directivaV3 = new RegExp('@' + 'tailwind\\s+(base|components|utilities|screens|variants)')

let hayImportV4 = false
for (const hoja of hojas) {
  const contenido = leer(hoja)

  if (/@import\s+['"]tailwindcss['"]/.test(contenido)) hayImportV4 = true

  if (directivaV3.test(contenido)) {
    anotar(hoja, 'usa las directivas de Tailwind v3. En v4 se sustituyen por @import "tailwindcss"')
  }
  if (/\btheme\(\s*['"]/.test(contenido)) {
    anotar(hoja, 'usa la función theme() de v3. En v4 se leen las variables CSS: var(--color-...)')
  }
  if (/@layer\s+utilities\b/.test(contenido)) {
    anotar(hoja, 'define utilidades con @layer utilities (v3). En v4 se usa la directiva @utility')
  }
}

if (hojas.length === 0) {
  anotar('src', 'no hay ninguna hoja de estilos')
} else if (!hayImportV4) {
  anotar('src', 'ninguna hoja de estilos hace @import "tailwindcss"')
}

// ---------------------------------------------------------------------------
// 5. Clases eliminadas en v4. Solo las que no existen en v4 con otro significado:
//    un `shadow-sm` o un `rounded-sm` son válidos en ambas y no se pueden distinguir.
// ---------------------------------------------------------------------------
const clasesRetiradas = [
  {
    patron: /\b(bg|text|border|ring|divide|placeholder)-opacity-\d+\b/,
    consejo: 'los modificadores de opacidad se retiraron; usa la sintaxis de color: bg-sky-500/50',
  },
  {
    patron: /\bflex-(grow|shrink)\b/,
    consejo: 'flex-grow-* y flex-shrink-* se retiraron; usa grow-* y shrink-*',
  },
  {
    patron: /\bdecoration-(slice|clone)\b/,
    consejo: 'usa box-decoration-slice y box-decoration-clone',
  },
  { patron: /\boverflow-ellipsis\b/, consejo: 'usa text-ellipsis' },
]

const fuentes = [
  ...archivosCon(join(raiz, 'src'), ['.ts', '.tsx']),
  ...(existe('index.html') ? [join(raiz, 'index.html')] : []),
]

for (const fuente of fuentes) {
  const lineas = leer(fuente).split('\n')
  lineas.forEach((linea, indice) => {
    for (const { patron, consejo } of clasesRetiradas) {
      const encontrado = patron.exec(linea)
      if (encontrado) {
        anotar(fuente, `línea ${indice + 1}: "${encontrado[0]}" es de Tailwind v3 — ${consejo}`)
      }
    }
  })
}

// ---------------------------------------------------------------------------
if (problemas.length > 0) {
  console.error('\n  Tailwind: se detectaron patrones de v3 sobre una instalación de v4.\n')
  for (const { archivo, mensaje } of problemas) {
    console.error(`  ${archivo}\n    ${mensaje}\n`)
  }
  console.error('  Contexto: docs/adr/0008-tailwind-v4.md\n')
  exit(1)
}

console.log(
  `Tailwind v4 coherente: ${hojas.length} hoja(s) y ${fuentes.length} fuente(s) revisadas.`,
)
