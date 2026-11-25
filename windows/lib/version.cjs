'use strict'

/** Versão semântica simples (1.2.3), com ou sem prefixo "v"; null se inválida. */
function parseVersion(text) {
  let s = String(text ?? '').trim()
  if (/^v/i.test(s)) s = s.slice(1)
  s = s.split(/[-+]/)[0]
  const parts = s.split('.')
  if (!parts.length || parts.some((p) => !/^\d+$/.test(p))) return null
  return parts.map(Number)
}

function compareVersions(a, b) {
  const x = parseVersion(a), y = parseVersion(b)
  if (!x || !y) return 0
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    const d = (x[i] ?? 0) - (y[i] ?? 0)
    if (d !== 0) return d < 0 ? -1 : 1
  }
  return 0
}

const isInstaller = (name) => /\.exe$/i.test(name)

/** Interpreta GET /repos/{dono}/{repo}/releases/latest. Null para rascunho, pré-lançamento ou JSON inesperado. */
function parseRelease(payload) {
  if (!payload || typeof payload !== 'object' || payload.draft === true || payload.prerelease === true) return null
  const version = parseVersion(payload.tag_name)
  if (!version || typeof payload.html_url !== 'string') return null
  const assets = Array.isArray(payload.assets) ? payload.assets : []
  // Prefere o instalador versionado; o "Calc3D-Setup.exe" de nome fixo serve de reserva.
  const exe =
    assets.find((a) => isInstaller(a.name) && a.name !== 'Calc3D-Setup.exe') ?? assets.find((a) => isInstaller(a.name))
  return {
    version: version.join('.'),
    name: payload.name || payload.tag_name,
    notes: displayNotes(payload.body ?? ''),
    pageUrl: payload.html_url,
    installerUrl: exe?.browser_download_url ?? null,
  }
}

/** Monta a release a partir do destino do redirecionamento de /releases/latest (não tem limite de consultas). */
function fromLatestRedirect(location) {
  let url
  try { url = new URL(location) } catch { return null }
  const parts = url.pathname.split('/')
  const tagIndex = parts.lastIndexOf('tag')
  if (tagIndex < 0 || tagIndex + 1 >= parts.length) return null
  const tag = decodeURIComponent(parts[tagIndex + 1])
  const version = parseVersion(tag)
  if (!version) return null
  const download = new URL(url)
  download.pathname = url.pathname.replace('/releases/tag/', '/releases/download/') + '/Calc3D-Setup.exe'
  download.search = ''
  return { version: version.join('.'), name: `Calc3D ${tag}`, notes: [], pageUrl: url.href, installerUrl: download.href }
}

/** Notas em linhas simples: remove títulos/markdown e troca marcadores por "•". */
function displayNotes(body) {
  return String(body)
    .split(/\r?\n/)
    .map((raw) => {
      let line = raw.trim().replace(/^#+/, '').trim()
      if (/^[*-] /.test(line)) line = '• ' + line.slice(2)
      return line
    })
    .filter(Boolean)
}

module.exports = { parseVersion, compareVersions, parseRelease, fromLatestRedirect, displayNotes }
