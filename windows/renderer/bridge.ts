/** API que o Electron expõe em window.calc3d (veja windows/preload.cjs). */
export interface CatalogEntry {
  path: string
  name: string
  extension: string
  /** Pasta relativa à pasta do catálogo ("" se estiver na raiz). */
  folder: string
  modifiedAt: number
}

export interface SlicerInfo {
  id: string
  title: string
  installed: boolean
  icon: string | null
}

export interface ReleaseInfo {
  version: string
  name: string
  notes: string[]
  pageUrl: string
  installerUrl: string | null
}

export type UpdateCheck = { status: 'available' | 'upToDate'; release: ReleaseInfo } | { status: 'error' }

export interface DesktopBridge {
  platform: string
  setWindowTheme(dark: boolean): Promise<void>
  info(): Promise<{ version: string; platform: string }>
  catalog: {
    chooseFolder(): Promise<string | null>
    list(root: string): Promise<{ ok: true; files: CatalogEntry[]; pending: number } | { ok: false; error: string }>
    read(root: string, file: string): Promise<Uint8Array>
    upload(root: string): Promise<{ sent: string[]; failures: string[] } | null>
    download(root: string, file: string): Promise<string | null>
    trash(root: string, file: string): Promise<void>
    reveal(file: string): Promise<void>
  }
  slicers: {
    list(): Promise<SlicerInfo[]>
    open(id: string, root: string, file: string): Promise<void>
  }
  updates: {
    check(): Promise<UpdateCheck>
    install(release: ReleaseInfo): Promise<{ manual: boolean }>
    openPage(url: string): Promise<void>
  }
  onMenu(callback: (action: string) => void): () => void
}

declare global {
  interface Window {
    calc3d?: DesktopBridge
  }
}

export const bridge = (): DesktopBridge => {
  if (!window.calc3d) throw new Error('Recurso disponível apenas no app para desktop.')
  return window.calc3d
}
