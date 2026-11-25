import { create } from 'zustand'
import { embeddedImage3MF, importModelBytes, modelTriangles, selectPlate, type ImportedModel } from '@web/core/importer'
import { renderThumbnail } from '@web/core/render'
import { bridge, type CatalogEntry, type SlicerInfo } from '../bridge'

const FOLDER_KEY = 'calc3d.desktop.catalogFolder'

export type FileInfo = { state: 'ready'; data: ImportedModel } | { state: 'error'; message: string }

interface CatalogState {
  folder: string | null
  files: CatalogEntry[]
  selected: string | null
  search: string
  message: string | null
  refreshing: boolean
  info: Record<string, FileInfo>
  thumbs: Record<string, string>
  /** Mesa escolhida em arquivos com várias mesas fatiadas. */
  plateChoice: Record<string, number>
  slicers: SlicerInfo[]

  chooseFolder: () => Promise<void>
  disconnect: () => void
  refresh: () => Promise<void>
  select: (path: string | null) => void
  setSearch: (text: string) => void
  loadInfo: (file: CatalogEntry) => void
  loadThumb: (file: CatalogEntry) => void
  loadSlicers: () => Promise<void>
  /** Dados do arquivo já com a mesa escolhida; null se ainda não leu ou falhou. */
  data: (file: CatalogEntry) => ImportedModel | null
  setPlate: (path: string, index: number) => void
  upload: () => Promise<void>
  download: (file: CatalogEntry) => Promise<void>
  trash: (file: CatalogEntry) => Promise<void>
  reveal: (file: CatalogEntry) => void
  openInSlicer: (file: CatalogEntry, slicerId: string) => Promise<void>
  say: (message: string | null) => void
}

// Lê no máximo dois arquivos por vez (miniaturas de uma pasta grande não travam a tela).
let running = 0
const waiting: (() => void)[] = []
function enqueue<T>(job: () => Promise<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    const start = () => {
      running++
      job().then(resolve, reject).finally(() => {
        running--
        waiting.shift()?.()
      })
    }
    if (running < 2) start()
    else waiting.push(start)
  })
}

const requested = new Set<string>()
/** true na primeira vez que o pedido aparece (evita ler o mesmo arquivo várias vezes). */
const claim = (kind: string, file: CatalogEntry) => {
  const id = `${kind}:${file.path}:${file.modifiedAt}`
  if (requested.has(id)) return false
  requested.add(id)
  return true
}

export const useCatalog = create<CatalogState>((set, get) => ({
  folder: localStorage.getItem(FOLDER_KEY),
  files: [],
  selected: null,
  search: '',
  message: null,
  refreshing: false,
  info: {},
  thumbs: {},
  plateChoice: {},
  slicers: [],

  say: (message) => set({ message }),

  chooseFolder: async () => {
    const folder = await bridge().catalog.chooseFolder()
    if (!folder) return
    localStorage.setItem(FOLDER_KEY, folder)
    requested.clear()
    set({ folder, selected: null, info: {}, thumbs: {}, files: [], message: null })
    await get().refresh()
  },

  disconnect: () => {
    localStorage.removeItem(FOLDER_KEY)
    requested.clear()
    set({ folder: null, files: [], selected: null, info: {}, thumbs: {}, message: null })
  },

  refresh: async () => {
    const { folder } = get()
    if (!folder) return
    set({ refreshing: true })
    const result = await bridge().catalog.list(folder)
    if (!result.ok) {
      set({ refreshing: false, message: 'Não foi possível abrir a pasta do catálogo. Ela existe e está acessível?' })
      return
    }
    const alive = new Set(result.files.map((f) => f.path))
    const fresh = (record: Record<string, unknown>) => Object.fromEntries(Object.entries(record).filter(([p]) => alive.has(p)))
    // Arquivos que mudaram precisam ser lidos de novo: o pedido é identificado pela data de modificação.
    const previous = new Map(get().files.map((f) => [f.path, f.modifiedAt]))
    const changed = new Set(result.files.filter((f) => previous.has(f.path) && previous.get(f.path) !== f.modifiedAt).map((f) => f.path))
    const keep = (record: Record<string, unknown>) => Object.fromEntries(Object.entries(fresh(record)).filter(([p]) => !changed.has(p)))
    set((s) => ({
      files: result.files,
      refreshing: false,
      selected: s.selected && alive.has(s.selected) ? s.selected : null,
      info: keep(s.info) as Record<string, FileInfo>,
      thumbs: keep(s.thumbs) as Record<string, string>,
      message: result.pending > 0 ? `${result.pending} arquivo(s) ainda sendo baixado(s) da nuvem; atualize em instantes.` : null,
    }))
  },

  select: (selected) => set({ selected }),
  setSearch: (search) => set({ search }),

  loadInfo: (file) => {
    const folder = get().folder
    if (!folder || get().info[file.path] || !claim('info', file)) return
    enqueue(async () => {
      try {
        const bytes = await bridge().catalog.read(folder, file.path)
        const data = importModelBytes(file.path, bytes)
        set((s) => ({ info: { ...s.info, [file.path]: { state: 'ready', data } } }))
      } catch (e) {
        set((s) => ({ info: { ...s.info, [file.path]: { state: 'error', message: (e as Error).message } } }))
      }
    })
  },

  // Imagem embutida no 3MF (capa do fatiador); sem ela, desenha a malha (STL ou 3MF sem imagem).
  loadThumb: (file) => {
    const folder = get().folder
    if (!folder || get().thumbs[file.path] || !claim('thumb', file)) return
    enqueue(async () => {
      try {
        const bytes = await bridge().catalog.read(folder, file.path)
        let blob: Blob | null = null
        if (file.extension === '3mf') {
          const png = embeddedImage3MF(bytes)
          if (png) blob = new Blob([png as BlobPart], { type: 'image/png' })
        }
        if (!blob) {
          const triangles = modelTriangles(file.path, bytes)
          blob = triangles ? await renderThumbnail(triangles) : null
        }
        if (blob) set((s) => ({ thumbs: { ...s.thumbs, [file.path]: URL.createObjectURL(blob) } }))
      } catch {
        // Sem miniatura: a lista mostra o ícone padrão.
      }
    })
  },

  loadSlicers: async () => set({ slicers: await bridge().slicers.list() }),

  data: (file) => {
    const entry = get().info[file.path]
    if (entry?.state !== 'ready') return null
    const { data } = entry
    if (data.plates.length <= 1) return data
    const wanted = get().plateChoice[file.path] ?? data.plates[0].index
    return selectPlate(data, data.plates.find((p) => p.index === wanted) ?? data.plates[0])
  },

  setPlate: (path, index) => set((s) => ({ plateChoice: { ...s.plateChoice, [path]: index } })),

  upload: async () => {
    const { folder, refresh } = get()
    if (!folder) return
    const result = await bridge().catalog.upload(folder)
    if (!result) return
    await refresh()
    const parts: string[] = []
    if (result.sent.length) parts.push(result.sent.length === 1 ? '1 arquivo enviado ao catálogo ✔' : `${result.sent.length} arquivos enviados ao catálogo ✔`)
    if (result.failures.length) parts.push('Falhou: ' + result.failures.join('; '))
    set({ message: parts.join(' '), ...(result.sent.length === 1 ? { selected: result.sent[0] } : {}) })
  },

  download: async (file) => {
    const { folder } = get()
    if (!folder) return
    try {
      const saved = await bridge().catalog.download(folder, file.path)
      if (saved) set({ message: `"${saved}" baixado ✔` })
    } catch (e) {
      set({ message: `Não foi possível baixar "${file.name}": ${(e as Error).message}` })
    }
  },

  trash: async (file) => {
    const { folder, refresh } = get()
    if (!folder) return
    let message: string
    try {
      await bridge().catalog.trash(folder, file.path)
      message = `"${file.name}.${file.extension}" movido para a Lixeira ✔`
    } catch (e) {
      message = `Não foi possível excluir "${file.name}": ${(e as Error).message}`
    }
    set({ selected: get().selected === file.path ? null : get().selected })
    await refresh()
    set((s) => ({ message: [message, s.message].filter(Boolean).join(' ') }))
  },

  reveal: (file) => void bridge().catalog.reveal(file.path),

  openInSlicer: async (file, slicerId) => {
    const { folder } = get()
    if (!folder) return
    try {
      await bridge().slicers.open(slicerId, folder, file.path)
    } catch (e) {
      const title = get().slicers.find((s) => s.id === slicerId)?.title ?? 'fatiador'
      set({ message: `Não foi possível abrir no ${title}: ${(e as Error).message.replace(/^Error invoking remote method '[^']*': (Error: )?/, '')}` })
    }
  },
}))

export function visibleFiles(files: CatalogEntry[], search: string): CatalogEntry[] {
  const q = search.trim().toLowerCase()
  return q ? files.filter((f) => f.name.toLowerCase().includes(q) || f.folder.toLowerCase().includes(q)) : files
}
