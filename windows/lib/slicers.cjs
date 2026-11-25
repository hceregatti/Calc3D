'use strict'
const fs = require('node:fs')
const path = require('node:path')

/** Fatiadores em que um modelo do catálogo pode ser aberto. */
const SLICERS = [
  { id: 'bambuStudio', title: 'Bambu Studio', keyword: 'bambustudio' },
  { id: 'crealityPrint', title: 'Creality Print', keyword: 'crealityprint' },
]

const normalize = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '')

/** Pastas onde o Windows instala programas (e, no macOS/Linux, onde ficam os apps). */
function defaultRoots(platform = process.platform, env = process.env) {
  if (platform === 'win32') {
    return [env.ProgramFiles, env['ProgramFiles(x86)'], env.ProgramW6432, env.LOCALAPPDATA && path.join(env.LOCALAPPDATA, 'Programs')]
      .filter(Boolean)
  }
  if (platform === 'darwin') return ['/Applications', env.HOME && path.join(env.HOME, 'Applications')].filter(Boolean)
  return ['/usr/bin', '/usr/local/bin', '/opt']
}

const isExecutable = (name, platform) => (platform === 'win32' ? /\.exe$/i.test(name) : platform === 'darwin' ? /\.app$/i.test(name) : true)

const readDir = (dir) => { try { return fs.readdirSync(dir, { withFileTypes: true }) } catch { return [] } }

/**
 * Procura o executável do fatiador nas pastas de programas. Casa pelo nome (ignorando espaços, hífens
 * e versão: "Creality Print 6.1", "bambu-studio.exe") até dois níveis de profundidade.
 */
function findSlicer(slicer, { roots = defaultRoots(), platform = process.platform } = {}) {
  for (const root of roots) {
    for (const entry of readDir(root)) {
      const full = path.join(root, entry.name)
      const matches = normalize(entry.name).includes(slicer.keyword)
      if (platform === 'darwin') {
        if (matches && isExecutable(entry.name, platform)) return full
        continue
      }
      if (entry.isFile()) {
        if (matches && isExecutable(entry.name, platform)) return full
        continue
      }
      if (!entry.isDirectory()) continue
      // Pasta do app (ou do fabricante, ex.: "Creality\Creality Print 6.1"): procura o .exe dentro.
      const exe = findExecutable(full, slicer.keyword, platform, 2)
      if (exe) return exe
    }
  }
  return null
}

function findExecutable(dir, keyword, platform, depth) {
  const entries = readDir(dir)
  for (const e of entries) {
    if (e.isFile() && isExecutable(e.name, platform) && normalize(e.name).includes(keyword)) return path.join(dir, e.name)
  }
  if (depth > 1) {
    for (const e of entries) {
      if (!e.isDirectory()) continue
      const found = findExecutable(path.join(dir, e.name), keyword, platform, depth - 1)
      if (found) return found
    }
  }
  return null
}

module.exports = { SLICERS, findSlicer, defaultRoots, normalize }
