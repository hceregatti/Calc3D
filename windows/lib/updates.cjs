'use strict'
const { parseRelease, fromLatestRedirect, compareVersions } = require('./version.cjs')

const REPO = 'hceregatti/Calc3D'
const API = `https://api.github.com/repos/${REPO}/releases/latest`
const PAGE = `https://github.com/${REPO}/releases/latest`

/**
 * Última release publicada. Consulta a API do GitHub; se ela recusar (limite de 60 consultas por hora sem
 * login), usa o redirecionamento da página pública de releases, que não tem esse limite.
 * `fetchFn` é injetável para teste.
 */
async function fetchLatestRelease(fetchFn = fetch) {
  try {
    const res = await fetchFn(API, { headers: { Accept: 'application/vnd.github+json' }, signal: AbortSignal.timeout(15000) })
    if (res.status === 200) {
      const release = parseRelease(await res.json())
      if (release) return release
    }
  } catch { /* cai para a página pública */ }
  const res = await fetchFn(PAGE, { method: 'HEAD', redirect: 'manual', signal: AbortSignal.timeout(15000) })
  const location = res.headers.get('location')
  const release = location && fromLatestRedirect(new URL(location, PAGE).href)
  if (!release) throw new Error('Resposta inesperada do GitHub.')
  return release
}

/** { status: 'available' | 'upToDate', release } — ou lança erro se não conseguiu consultar. */
async function checkForUpdate(currentVersion, fetchFn = fetch) {
  const release = await fetchLatestRelease(fetchFn)
  return compareVersions(release.version, currentVersion) > 0 ? { status: 'available', release } : { status: 'upToDate', release }
}

module.exports = { fetchLatestRelease, checkForUpdate, PAGE }
