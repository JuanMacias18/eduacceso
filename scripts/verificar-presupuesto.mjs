#!/usr/bin/env node
/**
 * `test:budget` — presupuesto de tamaño del bundle inicial.
 *
 * CLAUDE.md, regla 15: bundle inicial < 180 KB gzip. Los estudiantes están en 3G rural
 * con datos prepago; cada KB se paga.
 *
 * "Inicial" no es "todo lo que hay en dist/": a partir del encargo 03 las rutas se cargan
 * de forma diferida y esos trozos no cuentan. Por eso se lee el manifiesto de Vite y se
 * recorre solo el grafo de imports estáticos desde la entrada. Los `dynamicImports` se
 * excluyen a propósito — son justamente lo que no se descarga al abrir la app.
 *
 * El presupuesto de LCP (< 2.5 s en 3G) llega con Lighthouse CI en el encargo 03, cuando
 * exista un dashboard que medir.
 */
import { gzipSync } from 'node:zlib'
import { readFileSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { exit } from 'node:process'

const PRESUPUESTO_JS_GZIP = 180 * 1024

const raiz = process.cwd()
const dist = join(raiz, 'dist')
const rutaManifiesto = join(dist, '.vite', 'manifest.json')

const kb = (bytes) => `${(bytes / 1024).toFixed(1)} KB`

let manifiesto
try {
  manifiesto = JSON.parse(readFileSync(rutaManifiesto, 'utf8'))
} catch {
  console.error(
    `\n  No se encontró ${relative(raiz, rutaManifiesto)}.\n` +
      '  Ejecuta `npm run build` antes, o usa `npm run test:budget`, que ya lo hace.\n',
  )
  exit(1)
}

/**
 * Recorre el grafo de imports estáticos desde las entradas.
 * Devuelve el conjunto de archivos que el navegador descarga en el primer arranque.
 */
function archivosDeArranque() {
  const entradas = Object.keys(manifiesto).filter((clave) => manifiesto[clave]?.isEntry)
  if (entradas.length === 0) {
    console.error('\n  El manifiesto no declara ninguna entrada (isEntry). Build incompleto.\n')
    exit(1)
  }

  const visitados = new Set()
  const js = new Set()
  const css = new Set()

  const recorrer = (clave) => {
    if (visitados.has(clave)) return
    visitados.add(clave)

    const registro = manifiesto[clave]
    if (!registro) return

    if (registro.file?.endsWith('.js')) js.add(registro.file)
    for (const hoja of registro.css ?? []) css.add(hoja)

    // Solo imports estáticos: `dynamicImports` es carga diferida y no cuenta.
    for (const importado of registro.imports ?? []) recorrer(importado)
  }

  for (const entrada of entradas) recorrer(entrada)

  return { js: [...js], css: [...css] }
}

function medir(archivoRelativo) {
  const ruta = join(dist, archivoRelativo)
  const contenido = readFileSync(ruta)
  return {
    archivo: archivoRelativo,
    crudo: statSync(ruta).size,
    gzip: gzipSync(contenido).length,
  }
}

const { js, css } = archivosDeArranque()
const medidasJs = js.map(medir)
const medidasCss = css.map(medir)

const totalJsGzip = medidasJs.reduce((suma, m) => suma + m.gzip, 0)
const totalCssGzip = medidasCss.reduce((suma, m) => suma + m.gzip, 0)

console.log('\n  Bundle inicial (imports estáticos desde la entrada)\n')
for (const m of [...medidasJs, ...medidasCss]) {
  console.log(`    ${m.archivo.padEnd(40)} ${kb(m.crudo).padStart(10)}  gzip ${kb(m.gzip)}`)
}

const porcentaje = ((totalJsGzip / PRESUPUESTO_JS_GZIP) * 100).toFixed(1)
console.log(
  `\n    JS inicial: ${kb(totalJsGzip)} gzip · presupuesto ${kb(PRESUPUESTO_JS_GZIP)} · ${porcentaje}% consumido`,
)
console.log(`    CSS inicial: ${kb(totalCssGzip)} gzip (fuera del presupuesto de JS)\n`)

if (totalJsGzip > PRESUPUESTO_JS_GZIP) {
  console.error(
    `  El bundle inicial excede el presupuesto en ${kb(totalJsGzip - PRESUPUESTO_JS_GZIP)} gzip.\n` +
      '  Antes de subir el número: mira si algo puede cargarse de forma diferida.\n' +
      '  El presupuesto está en CLAUDE.md, regla 15, y existe porque los estudiantes\n' +
      '  están en 3G rural con datos prepago.\n',
  )
  exit(1)
}
