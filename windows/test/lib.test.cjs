'use strict'
const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { compareVersions, parseVersion, parseRelease, fromLatestRedirect } = require('../lib/version.cjs')
const { listCatalog, uniqueTarget, uploadFiles, isInside } = require('../lib/catalog.cjs')
const { SLICERS, findSlicer } = require('../lib/slicers.cjs')

const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'calc3d-'))
const touch = (p, content = 'x') => { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, content) }

test('versões', () => {
  assert.deepEqual(parseVersion('v1.2.3-beta'), [1, 2, 3])
  assert.equal(parseVersion('abc'), null)
  assert.equal(compareVersions('1.10.0', '1.9.9'), 1)
  assert.equal(compareVersions('v1.2', '1.2.0'), 0)
  assert.equal(compareVersions('1.2.3', '1.3'), -1)
})

test('release do GitHub: prefere o instalador versionado e ignora rascunhos', () => {
  const payload = {
    tag_name: 'v2.0.1', name: 'Calc3D v2.0.1', body: '## Novidades\n- Item um\n* Item dois', html_url: 'https://github.com/x/y/releases/tag/v2.0.1',
    assets: [
      { name: 'Calc3D.dmg', browser_download_url: 'https://x/Calc3D.dmg' },
      { name: 'Calc3D-Setup.exe', browser_download_url: 'https://x/fixed.exe' },
      { name: 'Calc3D-Setup-2.0.1.exe', browser_download_url: 'https://x/versioned.exe' },
    ],
  }
  const r = parseRelease(payload)
  assert.equal(r.version, '2.0.1')
  assert.equal(r.installerUrl, 'https://x/versioned.exe')
  assert.deepEqual(r.notes, ['Novidades', '• Item um', '• Item dois'])
  assert.equal(parseRelease({ ...payload, draft: true }), null)
  assert.equal(parseRelease({ ...payload, prerelease: true }), null)
  assert.equal(parseRelease({ ...payload, tag_name: 'nightly' }), null)
})

test('release pelo redirecionamento da página pública', () => {
  const r = fromLatestRedirect('https://github.com/hceregatti/Calc3D/releases/tag/v1.13.0')
  assert.equal(r.version, '1.13.0')
  assert.equal(r.installerUrl, 'https://github.com/hceregatti/Calc3D/releases/download/v1.13.0/Calc3D-Setup.exe')
  assert.equal(fromLatestRedirect('https://github.com/hceregatti/Calc3D/releases'), null)
})

test('catálogo lista 3MF/STL em subpastas, ignora ocultos e ordena naturalmente', () => {
  const root = tmp()
  touch(path.join(root, 'peça 10.3mf'))
  touch(path.join(root, 'peça 2.STL'))
  touch(path.join(root, 'Suportes', 'gancho.3mf'))
  touch(path.join(root, 'leia.txt'))
  touch(path.join(root, '.oculto.3mf'))
  touch(path.join(root, '~$temp.3mf'))
  const { files } = listCatalog(root)
  assert.deepEqual(files.map((f) => f.name), ['gancho', 'peça 2', 'peça 10'])
  assert.deepEqual(files.map((f) => f.folder), ['Suportes', '', ''])
  assert.deepEqual(files.map((f) => f.extension), ['3mf', 'stl', '3mf'])
  assert.throws(() => listCatalog(path.join(root, 'nao-existe')), { code: 'folderUnavailable' })
})

test('envio não sobrescreve: nomes repetidos viram "nome 2"', () => {
  const root = tmp(), src = tmp()
  touch(path.join(root, 'a.3mf'), 'antigo')
  touch(path.join(src, 'a.3mf'), 'novo')
  touch(path.join(src, 'b.txt'))
  const { sent, failures } = uploadFiles(root, [path.join(src, 'a.3mf'), path.join(src, 'b.txt')])
  assert.equal(path.basename(sent[0]), 'a 2.3mf')
  assert.equal(fs.readFileSync(path.join(root, 'a.3mf'), 'utf8'), 'antigo')
  assert.equal(failures.length, 1)
  assert.equal(path.basename(uniqueTarget(root, 'a.3mf')), 'a 3.3mf')
})

test('isInside impede sair da pasta do catálogo', () => {
  const root = tmp()
  assert.equal(isInside(root, path.join(root, 'x', 'a.3mf')), true)
  assert.equal(isInside(root, path.join(root, '..', 'a.3mf')), false)
  assert.equal(isInside(root, root), false)
})

test('fatiadores são achados por nome, mesmo dentro da pasta do fabricante', () => {
  const programs = tmp()
  touch(path.join(programs, 'Bambu Studio', 'bambu-studio.exe'))
  touch(path.join(programs, 'Bambu Studio', 'unins000.exe'))
  touch(path.join(programs, 'Creality', 'Creality Print 6.1', 'CrealityPrint.exe'))
  const opts = { roots: [programs], platform: 'win32' }
  const [bambu, creality] = SLICERS
  assert.equal(findSlicer(bambu, opts), path.join(programs, 'Bambu Studio', 'bambu-studio.exe'))
  assert.equal(findSlicer(creality, opts), path.join(programs, 'Creality', 'Creality Print 6.1', 'CrealityPrint.exe'))
  assert.equal(findSlicer(bambu, { roots: [tmp()], platform: 'win32' }), null)
})

const { checkForUpdate } = require('../lib/updates.cjs')

test('atualização: usa a API e cai para o redirecionamento quando ela recusa', async () => {
  const release = { tag_name: 'v9.0.0', html_url: 'https://github.com/x/y/releases/tag/v9.0.0', assets: [] }
  const ok = async () => ({ status: 200, json: async () => release })
  assert.equal((await checkForUpdate('1.0.0', ok)).status, 'available')
  assert.equal((await checkForUpdate('9.0.0', ok)).status, 'upToDate')

  const limited = async (url, opts) =>
    opts?.method === 'HEAD'
      ? { status: 302, headers: new Headers({ location: 'https://github.com/hceregatti/Calc3D/releases/tag/v9.1.0' }) }
      : { status: 403, json: async () => ({}) }
  const result = await checkForUpdate('1.0.0', limited)
  assert.equal(result.release.version, '9.1.0')
  assert.match(result.release.installerUrl, /v9\.1\.0\/Calc3D-Setup\.exe$/)
})
