import { useEffect, useState } from 'react'
import { uid } from './core/models'

/**
 * Logos e fotos ficam no IndexedDB do navegador (o localStorage é pequeno demais),
 * já reduzidos para não pesar no armazenamento nem no PDF.
 */
const DB_NAME = 'calc3d'
const STORE = 'images'

let dbPromise: Promise<IDBDatabase> | null = null
function db(): Promise<IDBDatabase> {
  dbPromise ??= new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1)
    request.onupgradeneeded = () => request.result.createObjectStore(STORE)
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
  return dbPromise
}

async function tx<T>(mode: IDBTransactionMode, run: (store: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  const database = await db()
  return new Promise((resolve, reject) => {
    const request = run(database.transaction(STORE, mode).objectStore(STORE))
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

const urls = new Map<string, string>()
const listeners = new Set<() => void>()

export async function getImageBlob(id: string): Promise<Blob | undefined> {
  return tx('readonly', (s) => s.get(id) as IDBRequest<Blob | undefined>)
}

export async function putImageBlob(id: string, blob: Blob) {
  await tx('readwrite', (s) => s.put(blob, id))
}

export async function allImageIds(): Promise<string[]> {
  return (await tx('readonly', (s) => s.getAllKeys())).map(String)
}

/** Remove imagens que não são mais usadas por nenhum orçamento nem pelo perfil. */
export async function pruneImages(keep: Set<string>) {
  for (const id of await allImageIds()) {
    if (keep.has(id)) continue
    await tx('readwrite', (s) => s.delete(id))
    const url = urls.get(id)
    if (url) URL.revokeObjectURL(url)
    urls.delete(id)
  }
}

export type ImageKind = 'product' | 'logo'

/** Redimensiona e guarda a imagem; PNG para logos e imagens com transparência, JPEG para fotos. */
export async function importImage(file: Blob, kind: ImageKind): Promise<string> {
  const bitmap = await createImageBitmap(file).catch(() => {
    throw new Error('Não foi possível abrir esta imagem.')
  })
  const max = kind === 'logo' ? 800 : 1200
  const scale = Math.min(1, max / Math.max(bitmap.width, bitmap.height))
  const canvas = document.createElement('canvas')
  canvas.width = Math.max(1, Math.round(bitmap.width * scale))
  canvas.height = Math.max(1, Math.round(bitmap.height * scale))
  const context = canvas.getContext('2d')!
  context.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
  bitmap.close()

  let hasAlpha = kind === 'logo'
  if (!hasAlpha && file.type !== 'image/jpeg') {
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data
    for (let i = 3; i < pixels.length; i += 4) {
      if (pixels[i] < 255) {
        hasAlpha = true
        break
      }
    }
  }
  const blob = await new Promise<Blob | null>((resolve) =>
    canvas.toBlob(resolve, hasAlpha ? 'image/png' : 'image/jpeg', 0.85),
  )
  if (!blob) throw new Error('Não foi possível processar esta imagem.')
  const id = uid()
  await putImageBlob(id, blob)
  return id
}

export async function imageURL(id: string): Promise<string | null> {
  const cached = urls.get(id)
  if (cached) return cached
  const blob = await getImageBlob(id)
  if (!blob) return null
  const url = URL.createObjectURL(blob)
  urls.set(id, url)
  listeners.forEach((l) => l())
  return url
}

/** URL de exibição de uma imagem guardada (null enquanto carrega ou se não existir). */
export function useImage(id: string | null): string | null {
  const [url, setUrl] = useState<string | null>(id ? (urls.get(id) ?? null) : null)
  useEffect(() => {
    let active = true
    if (!id) {
      setUrl(null)
      return
    }
    setUrl(urls.get(id) ?? null)
    imageURL(id).then((u) => active && setUrl(u))
    return () => {
      active = false
    }
  }, [id])
  return url
}

export async function blobToDataURL(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result))
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(blob)
  })
}

export async function dataURLToBlob(dataURL: string): Promise<Blob> {
  return (await fetch(dataURL)).blob()
}
