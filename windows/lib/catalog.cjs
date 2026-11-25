'use strict'
const fs = require('node:fs')
const path = require('node:path')

const SUPPORTED = new Set(['.3mf', '.stl'])

/** Lista os 3MF/STL da pasta (e subpastas), em ordem natural de nome. Lança 'folderUnavailable' se a pasta não existir. */
function listCatalog(root) {
  let stat
  try { stat = fs.statSync(root) } catch { stat = null }
  if (!stat || !stat.isDirectory()) throw Object.assign(new Error('folderUnavailable'), { code: 'folderUnavailable' })
  const files = []
  const walk = (dir) => {
    let entries
    try { entries = fs.readdirSync(dir, { withFileTypes: true }) } catch { return }
    for (const entry of entries) {
      // Ignora ocultos e temporários do Office/OneDrive ("~$…", ".nome").
      if (entry.name.startsWith('.') || entry.name.startsWith('~$')) continue
      const full = path.join(dir, entry.name)
      if (entry.isDirectory()) { walk(full); continue }
      if (!entry.isFile() || !SUPPORTED.has(path.extname(entry.name).toLowerCase())) continue
      let mtime
      try { mtime = fs.statSync(full).mtimeMs } catch { continue }
      files.push({
        path: full,
        name: path.basename(entry.name, path.extname(entry.name)),
        extension: path.extname(entry.name).slice(1).toLowerCase(),
        folder: path.relative(root, dir).split(path.sep).join('/'),
        modifiedAt: mtime,
      })
    }
  }
  walk(root)
  const collator = new Intl.Collator('pt-BR', { numeric: true, sensitivity: 'base' })
  files.sort((a, b) => collator.compare(a.name, b.name))
  return { files, pending: 0 }
}

/** Caminho livre para copiar `fileName` em `dir`, sem sobrescrever: "nome 2.3mf", "nome 3.3mf"… */
function uniqueTarget(dir, fileName) {
  const ext = path.extname(fileName)
  const base = path.basename(fileName, ext)
  let target = path.join(dir, fileName)
  for (let n = 2; fs.existsSync(target); n++) target = path.join(dir, `${base} ${n}${ext}`)
  return target
}

/** Copia os arquivos para a pasta do catálogo, sem sobrescrever nenhum. */
function uploadFiles(root, sources) {
  const sent = []
  const failures = []
  for (const source of sources) {
    if (!SUPPORTED.has(path.extname(source).toLowerCase())) {
      failures.push(`${path.basename(source)}: formato não suportado`)
      continue
    }
    try {
      const target = uniqueTarget(root, path.basename(source))
      fs.copyFileSync(source, target, fs.constants.COPYFILE_EXCL)
      sent.push(target)
    } catch (e) {
      failures.push(`${path.basename(source)}: ${e.message}`)
    }
  }
  return { sent, failures }
}

/** Garante que o caminho está dentro da pasta do catálogo (impede ler/excluir fora dela). */
function isInside(root, file) {
  const rel = path.relative(path.resolve(root), path.resolve(file))
  return rel !== '' && !rel.startsWith('..') && !path.isAbsolute(rel)
}

module.exports = { SUPPORTED, listCatalog, uniqueTarget, uploadFiles, isInside }
