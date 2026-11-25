import react from '@vitejs/plugin-react'
import path from 'node:path'
import { defineConfig } from 'vite'

const web = path.resolve(__dirname, '../../web')
const modules = (name: string) => path.join(web, 'node_modules', name)

// O app Windows reaproveita o código da versão web (web/src) e acrescenta o que é só do desktop.
// As bibliotecas vêm sempre de web/node_modules, para não existirem duas cópias do React.
export default defineConfig({
  root: __dirname,
  base: './',
  publicDir: path.join(web, 'public'),
  plugins: [react()],
  resolve: {
    alias: {
      '@web': path.join(web, 'src'),
      react: modules('react'),
      'react-dom': modules('react-dom'),
      zustand: modules('zustand'),
      'lucide-react': modules('lucide-react'),
      fflate: modules('fflate'),
    },
  },
  server: { fs: { allow: [path.resolve(__dirname, '../..')] } },
  build: { outDir: path.resolve(__dirname, '../dist'), emptyOutDir: true },
})
