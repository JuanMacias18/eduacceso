/**
 * Módulo académico: catálogo, cohortes, matrícula y cursos.
 *
 * Es el módulo base del dominio. `contenido` y `evaluacion` pueden importar de aquí;
 * este módulo NO puede importar de ellos — la regla está en eslint.config.js y romperla
 * hace fallar `npm run lint`, y con él `npm run verify`.
 */
// Commit de demostracion: viola la direccion de dependencias a proposito, para
// comprobar que el CI la rechaza. Se revierte inmediatamente despues.
import '@/evaluacion'

export {}
