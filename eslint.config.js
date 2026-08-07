import js from '@eslint/js'
import prettier from 'eslint-config-prettier'
import reactHooks from 'eslint-plugin-react-hooks'
import globals from 'globals'
import tseslint from 'typescript-eslint'

/**
 * Dirección de dependencias entre módulos del dominio (CLAUDE.md, "Estructura"):
 * `contenido` y `evaluacion` pueden importar de `academico`; lo contrario rompe el build.
 *
 * Los patrones cubren las dos formas de escribir el import: por alias (`@/evaluacion/...`)
 * y relativa (`../evaluacion/...`). `allowTypeImports: false` es deliberado: un `import type`
 * desaparece al compilar, pero sigue siendo un acoplamiento en la cabeza de quien lee.
 */
const importsProhibidosEnAcademico = [
  {
    group: ['**/contenido', '**/contenido/**', '**/evaluacion', '**/evaluacion/**'],
    message:
      'academico no puede importar de contenido ni de evaluacion. La dependencia va en el otro sentido (ver CLAUDE.md). Si necesitas algo compartido, va en shared.',
    allowTypeImports: false,
  },
]

export default tseslint.config(
  {
    ignores: ['dist/**', 'coverage/**', 'node_modules/**', 'supabase/.temp/**'],
  },

  js.configs.recommended,
  tseslint.configs.recommended,

  // Código de la aplicación: navegador.
  {
    files: ['src/**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2023,
      globals: globals.browser,
    },
    plugins: { 'react-hooks': reactHooks },
    rules: {
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',
    },
  },

  // Herramientas del repo: Node.
  {
    files: ['scripts/**/*.mjs', 'vite.config.ts', 'eslint.config.js', '*.config.{js,ts}'],
    languageOptions: {
      ecmaVersion: 2023,
      globals: globals.node,
    },
  },

  // La regla de aptitud del punto 10.2 del plan.
  {
    files: ['src/academico/**/*.{ts,tsx}'],
    rules: {
      '@typescript-eslint/no-restricted-imports': [
        'error',
        { patterns: importsProhibidosEnAcademico },
      ],
    },
  },

  // Prettier al final: apaga las reglas de formato para que no compitan.
  prettier,
)
