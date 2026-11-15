import { unzipSync } from 'fflate'

export interface ImportedModel {
  name: string
  weightGrams: number | null
  durationSeconds: number | null
}

/**
 * Lê o nome do modelo e, em arquivos 3MF fatiados (Bambu/Orca), o peso e o tempo
 * estimados pelo fatiador. Não estima nada a partir da geometria.
 */
export async function importModelFile(file: File): Promise<ImportedModel> {
  const name = file.name.replace(/\.[^.]+$/, '')
  const extension = file.name.split('.').pop()?.toLowerCase()
  const data = new Uint8Array(await file.arrayBuffer())
  if (extension === 'stl') {
    validateSTL(data)
    return { name, weightGrams: null, durationSeconds: null }
  }
  if (extension === '3mf') return import3MF(data, name)
  throw new Error('Escolha um arquivo STL ou 3MF.')
}

export function validateSTL(data: Uint8Array) {
  if (data.length === 0) throw new Error('O arquivo STL está vazio ou inválido.')
  const head = new TextDecoder().decode(data.subarray(0, Math.min(data.length, 1024))).trim().toLowerCase()
  if (head.startsWith('solid') && new TextDecoder().decode(data).toLowerCase().includes('facet')) return
  if (data.length < 84) throw new Error('O arquivo STL está vazio ou inválido.')
  const triangles = new DataView(data.buffer, data.byteOffset + 80, 4).getUint32(0, true)
  if (triangles === 0 || 84 + triangles * 50 !== data.length) throw new Error('O arquivo STL está vazio ou inválido.')
}

export function import3MF(data: Uint8Array, name: string): ImportedModel {
  let entries: string[] = []
  let files: Record<string, Uint8Array>
  try {
    files = unzipSync(data, {
      filter: (f) => {
        entries.push(f.name)
        return f.name.toLowerCase() === 'metadata/slice_info.config' && f.originalSize <= 1024 * 1024
      },
    })
  } catch {
    throw new Error('Não foi possível ler este arquivo 3MF.')
  }
  entries = entries.map((e) => e.toLowerCase())
  if (!entries.includes('3d/3dmodel.model')) throw new Error('Não foi possível ler este arquivo 3MF.')

  const sliceInfo = Object.values(files)[0]
  if (!sliceInfo) return { name, weightGrams: null, durationSeconds: null }
  return { name, ...parseSliceInfo(new TextDecoder().decode(sliceInfo)) }
}

export function parseSliceInfo(xml: string): Omit<ImportedModel, 'name'> {
  const doc = new DOMParser().parseFromString(xml, 'application/xml')
  if (doc.getElementsByTagName('parsererror').length) throw new Error('Não foi possível ler este arquivo 3MF.')
  const decimal = (v: string | null) => {
    const n = v === null ? NaN : Number(v)
    return Number.isFinite(n) && n > 0 ? n : null
  }
  const plates = [...doc.getElementsByTagName('plate')].map((plate) => {
    let prediction: number | null = null
    let weight = 0
    for (const meta of plate.getElementsByTagName('metadata')) {
      if (meta.getAttribute('key')?.toLowerCase() === 'prediction') prediction = decimal(meta.getAttribute('value'))
    }
    for (const filament of plate.getElementsByTagName('filament')) weight += decimal(filament.getAttribute('used_g')) ?? 0
    return { prediction, weight }
  })
  const estimated = plates.filter((p) => (p.prediction ?? 0) > 0)
  if (estimated.length !== 1) return { weightGrams: null, durationSeconds: null }
  const plate = estimated[0]
  return { weightGrams: plate.weight > 0 ? plate.weight : null, durationSeconds: plate.prediction }
}
