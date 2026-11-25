'use strict'
const { contextBridge, ipcRenderer } = require('electron')

const invoke = (channel, ...args) => ipcRenderer.invoke(channel, ...args)

/** API exposta ao app web (window.calc3d). Só passa dados simples; o acesso a arquivos fica no processo principal. */
contextBridge.exposeInMainWorld('calc3d', {
  platform: process.platform,
  setWindowTheme: (dark) => invoke('window:theme', Boolean(dark)),
  info: () => invoke('app:info'),
  catalog: {
    chooseFolder: () => invoke('catalog:choose'),
    list: (root) => invoke('catalog:list', root),
    read: (root, file) => invoke('catalog:read', root, file),
    upload: (root) => invoke('catalog:upload', root),
    download: (root, file) => invoke('catalog:download', root, file),
    trash: (root, file) => invoke('catalog:trash', root, file),
    reveal: (file) => invoke('catalog:reveal', file),
  },
  slicers: {
    list: () => invoke('slicers:list'),
    open: (id, root, file) => invoke('slicers:open', id, root, file),
  },
  updates: {
    check: () => invoke('updates:check'),
    install: (release) => invoke('updates:install', release),
    openPage: (url) => invoke('updates:openPage', url),
  },
  onMenu: (callback) => {
    const handler = (_event, action) => callback(action)
    ipcRenderer.on('menu', handler)
    return () => ipcRenderer.removeListener('menu', handler)
  },
})
