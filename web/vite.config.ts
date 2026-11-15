import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// base relativa: o build funciona em qualquer subpasta (GitHub Pages, Netlify, arquivo local servido).
export default defineConfig({
  base: './',
  plugins: [react()],
})
