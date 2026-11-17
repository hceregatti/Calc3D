import { allImageIds, blobToDataURL, dataURLToBlob, getImageBlob, putImageBlob } from './images'
import { useApp } from './store'

/** Os dados ficam só neste navegador; o backup permite levar tudo para outro aparelho. */
export async function exportBackup() {
  const { savedSettings, savedCompany, quotes, proposals, filaments } = useApp.getState()
  const images: Record<string, string> = {}
  for (const id of await allImageIds()) {
    const blob = await getImageBlob(id)
    if (blob) images[id] = await blobToDataURL(blob)
  }
  const payload = {
    app: 'calc3d-web',
    version: 1,
    exportedAt: new Date().toISOString(),
    settings: savedSettings,
    company: savedCompany,
    quotes,
    proposals,
    filaments,
    images,
  }
  const blob = new Blob([JSON.stringify(payload)], { type: 'application/json' })
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  link.download = `calc3d-backup-${new Date().toISOString().slice(0, 10)}.json`
  link.click()
  setTimeout(() => URL.revokeObjectURL(link.href), 1000)
}

export async function importBackup(file: File) {
  let payload: any
  try {
    payload = JSON.parse(await file.text())
  } catch {
    throw new Error('Arquivo de backup inválido.')
  }
  if (payload?.app !== 'calc3d-web' || !Array.isArray(payload.quotes) || !Array.isArray(payload.proposals)) {
    throw new Error('Este arquivo não é um backup do Calc3D.')
  }
  for (const [id, dataURL] of Object.entries(payload.images ?? {})) {
    if (typeof dataURL === 'string' && dataURL.startsWith('data:image/')) {
      await putImageBlob(id, await dataURLToBlob(dataURL))
    }
  }
  useApp.getState().replaceAll({
    settings: payload.settings,
    company: payload.company,
    quotes: payload.quotes,
    proposals: payload.proposals,
    filaments: Array.isArray(payload.filaments) ? payload.filaments : [],
  })
}
