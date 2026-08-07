import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

// Tailwind v4 se integra por plugin de Vite: no hay postcss.config ni tailwind.config.
// Ver docs/adr/0008-tailwind-v4.md antes de tocar esto.
//
// La configuración de Vitest vive aquí a propósito: un vitest.config.ts aparte no hereda
// los alias y acabarían desincronizados.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  test: {
    include: ['src/**/*.test.{ts,tsx}'],
    environment: 'node',
  },
})
