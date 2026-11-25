'use strict'
const { app, BrowserWindow, Menu, dialog, ipcMain, nativeTheme, net, protocol, shell } = require('electron')
const { spawn } = require('node:child_process')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { pathToFileURL } = require('node:url')
const { SUPPORTED, listCatalog, uploadFiles, isInside } = require('./lib/catalog.cjs')
const { SLICERS, findSlicer } = require('./lib/slicers.cjs')
const { checkForUpdate } = require('./lib/updates.cjs')

const SCHEME = 'app'
protocol.registerSchemesAsPrivileged([
  { scheme: SCHEME, privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } },
])

/** Onde está o app web compilado: ao lado do app empacotado, ou em windows/dist no desenvolvimento. */
const webRoot = () => (app.isPackaged ? path.join(process.resourcesPath, 'web') : path.join(__dirname, 'dist'))

let mainWindow = null
const send = (action) => mainWindow?.webContents.send('menu', action)

// MARK: janela e menu

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1260,
    height: 820,
    minWidth: 1040,
    minHeight: 640,
    title: 'Calc3D',
    icon: path.join(__dirname, 'assets', 'icon.png'),
    backgroundColor: nativeTheme.shouldUseDarkColors ? '#161614' : '#f6f6f4',
    // Barra de título própria (como a do macOS); o Windows desenha só os botões da janela por cima.
    titleBarStyle: 'hidden',
    titleBarOverlay: { color: '#00000000', symbolColor: nativeTheme.shouldUseDarkColors ? '#f2f1ee' : '#1c1c1a', height: 44 },
    trafficLightPosition: { x: 16, y: 14 },
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  })
  mainWindow.once('ready-to-show', () => mainWindow.show())
  // Links externos (ex.: sites de filamentos) abrem no navegador, nunca dentro do app.
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//i.test(url)) shell.openExternal(url)
    return { action: 'deny' }
  })
  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (!url.startsWith(`${SCHEME}://`)) {
      event.preventDefault()
      if (/^https?:\/\//i.test(url)) shell.openExternal(url)
    }
  })
  mainWindow.loadURL(`${SCHEME}://calc3d/index.html`)
  mainWindow.on('closed', () => { mainWindow = null })
}

// Mesma ordem dos atalhos do macOS (⌘1…⌘8).
const GO = [
  ['Início', 'home'], ['Calcular peça', 'printJob'], ['Peças', 'parts'], ['Filamentos', 'filaments'],
  ['Catálogo', 'catalog'], ['Orçamentos', 'proposals'], ['Parâmetros fixos', 'settings'], ['Personalizar orçamento', 'company'],
]

function buildMenu() {
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    {
      label: '&Arquivo',
      submenu: [
        { label: 'Nova peça', accelerator: 'CmdOrCtrl+N', click: () => send('newJob') },
        { label: 'Novo orçamento', accelerator: 'CmdOrCtrl+Shift+N', click: () => send('newProposal') },
        { type: 'separator' },
        { label: 'Parâmetros fixos…', accelerator: 'CmdOrCtrl+,', click: () => send('go:settings') },
        { type: 'separator' },
        { role: 'quit', label: 'Sair' },
      ],
    },
    {
      label: '&Editar',
      submenu: [
        { role: 'undo', label: 'Desfazer' }, { role: 'redo', label: 'Refazer' }, { type: 'separator' },
        { role: 'cut', label: 'Recortar' }, { role: 'copy', label: 'Copiar' }, { role: 'paste', label: 'Colar' },
        { role: 'selectAll', label: 'Selecionar tudo' },
        { type: 'separator' },
        { label: 'Copiar orçamento', accelerator: 'CmdOrCtrl+Shift+C', click: () => send('copySummary') },
      ],
    },
    {
      label: '&Ir',
      submenu: GO.map(([label, id], i) => ({ label, accelerator: `CmdOrCtrl+${i + 1}`, click: () => send(`go:${id}`) })),
    },
    {
      label: 'E&xibir',
      submenu: [
        { role: 'resetZoom', label: 'Tamanho normal' }, { role: 'zoomIn', label: 'Ampliar' }, { role: 'zoomOut', label: 'Reduzir' },
        { type: 'separator' }, { role: 'togglefullscreen', label: 'Tela cheia' },
        ...(app.isPackaged ? [] : [{ type: 'separator' }, { role: 'toggleDevTools' }]),
      ],
    },
    {
      label: 'A&juda',
      submenu: [
        { label: 'Verificar se há atualizações…', click: () => send('checkUpdates') },
        { label: 'Página do projeto', click: () => shell.openExternal('https://github.com/hceregatti/Calc3D') },
      ],
    },
  ]))
}

ipcMain.handle('window:theme', (_e, dark) => {
  // setTitleBarOverlay só existe no Windows/Linux; no macOS os botões são os do sistema.
  if (process.platform !== 'darwin') mainWindow?.setTitleBarOverlay({ color: '#00000000', symbolColor: dark ? '#f2f1ee' : '#1c1c1a', height: 44 })
})

// MARK: IPC — catálogo

/** Valida que o arquivo é um 3MF/STL dentro da pasta do catálogo informada. */
function catalogFile(root, file) {
  if (typeof root !== 'string' || typeof file !== 'string' || !isInside(root, file) || !SUPPORTED.has(path.extname(file).toLowerCase())) {
    throw new Error('Arquivo fora da pasta do catálogo.')
  }
  return file
}

ipcMain.handle('catalog:choose', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: 'Escolher a pasta do catálogo',
    message: 'Pasta com os arquivos 3MF/STL já configurados, compartilhada (OneDrive, Google Drive, Dropbox, rede…).',
    properties: ['openDirectory', 'createDirectory'],
    buttonLabel: 'Usar esta pasta',
  })
  return result.canceled ? null : result.filePaths[0]
})

ipcMain.handle('catalog:list', (_e, root) => {
  try {
    return { ok: true, ...listCatalog(root) }
  } catch (e) {
    return { ok: false, error: e.code === 'folderUnavailable' ? 'folderUnavailable' : e.message }
  }
})

ipcMain.handle('catalog:read', async (_e, root, file) => new Uint8Array(await fs.promises.readFile(catalogFile(root, file))))

ipcMain.handle('catalog:upload', async (_e, root) => {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: 'Enviar modelos para o catálogo',
    buttonLabel: 'Enviar',
    filters: [{ name: 'Modelos 3D', extensions: [...SUPPORTED].map((e) => e.slice(1)) }],
    properties: ['openFile', 'multiSelections'],
  })
  if (result.canceled) return null
  return uploadFiles(root, result.filePaths)
})

ipcMain.handle('catalog:download', async (_e, root, file) => {
  catalogFile(root, file)
  const result = await dialog.showSaveDialog(mainWindow, { title: 'Baixar modelo do catálogo', defaultPath: path.basename(file) })
  if (result.canceled || !result.filePath) return null
  await fs.promises.copyFile(file, result.filePath)
  return path.basename(result.filePath)
})

// Vai para a Lixeira (recuperável). Como a pasta é compartilhada, some para todos que a usam.
ipcMain.handle('catalog:trash', async (_e, root, file) => { await shell.trashItem(catalogFile(root, file)) })

ipcMain.handle('catalog:reveal', (_e, file) => { if (typeof file === 'string') shell.showItemInFolder(file) })

// MARK: IPC — fatiadores

ipcMain.handle('slicers:list', async () =>
  Promise.all(SLICERS.map(async ({ id, title, keyword }) => {
    const exe = findSlicer({ id, title, keyword })
    let icon = null
    // No macOS, getFileIcon em pacotes .app derruba o Electron; o ícone só é lido do .exe do Windows.
    if (exe && process.platform === 'win32') {
      try { icon = (await app.getFileIcon(exe, { size: 'large' })).toDataURL() } catch { /* sem ícone */ }
    }
    return { id, title, installed: Boolean(exe), icon }
  })))

// Abre uma cópia em pasta temporária: salvar no fatiador não altera o arquivo compartilhado do catálogo.
ipcMain.handle('slicers:open', async (_e, id, root, file) => {
  const slicer = SLICERS.find((s) => s.id === id)
  const exe = slicer && findSlicer(slicer)
  if (!slicer || !exe) throw new Error(`${slicer?.title ?? 'O fatiador'} não foi encontrado. Instale-o para abrir o modelo nele.`)
  catalogFile(root, file)
  const folder = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'Calc3D-Fatiador-'))
  const copy = path.join(folder, path.basename(file))
  await fs.promises.copyFile(file, copy)
  const child = process.platform === 'darwin' ? spawn('open', ['-a', exe, copy], { detached: true, stdio: 'ignore' })
    : spawn(exe, [copy], { detached: true, stdio: 'ignore' })
  child.on('error', () => {})
  child.unref()
})

// MARK: IPC — atualizações

ipcMain.handle('app:info', () => ({ version: app.getVersion(), platform: process.platform }))

ipcMain.handle('updates:check', async () => {
  try {
    return await checkForUpdate(app.getVersion(), (url, opts) => net.fetch(url, opts))
  } catch {
    return { status: 'error' }
  }
})

ipcMain.handle('updates:openPage', (_e, url) => {
  if (typeof url === 'string' && url.startsWith('https://github.com/hceregatti/Calc3D/')) shell.openExternal(url)
})

/** Baixa o instalador, abre e encerra o app para o instalador poder trocar os arquivos. */
ipcMain.handle('updates:install', async (_e, release) => {
  const url = release?.installerUrl
  if (typeof url !== 'string' || !url.startsWith('https://github.com/hceregatti/Calc3D/') || process.platform !== 'win32') {
    shell.openExternal(release?.pageUrl ?? 'https://github.com/hceregatti/Calc3D/releases/latest')
    return { manual: true }
  }
  const res = await net.fetch(url)
  if (!res.ok || !res.body) throw new Error('Falha ao baixar a atualização.')
  const folder = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'calc3d-update-'))
  const installer = path.join(folder, 'Calc3D-Setup.exe')
  await fs.promises.writeFile(installer, Buffer.from(await res.arrayBuffer()))
  spawn(installer, [], { detached: true, stdio: 'ignore' }).unref()
  setTimeout(() => app.quit(), 300)
  return { manual: false }
})

// MARK: ciclo de vida

if (!app.requestSingleInstanceLock()) {
  app.quit()
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore()
      mainWindow.focus()
    }
  })
  app.whenReady().then(() => {
    // Serve o app web por app://calc3d/, com origem estável para localStorage e IndexedDB.
    protocol.handle(SCHEME, (request) => {
      const { pathname } = new URL(request.url)
      const root = webRoot()
      const file = path.normalize(path.join(root, decodeURIComponent(pathname === '/' ? '/index.html' : pathname)))
      if (path.relative(root, file).startsWith('..')) return new Response('Not found', { status: 404 })
      return net.fetch(pathToFileURL(file).toString())
    })
    buildMenu()
    createWindow()
    app.on('activate', () => { if (!BrowserWindow.getAllWindows().length) createWindow() })
  })
  app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit() })
}
