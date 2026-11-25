import { unzipSync } from 'fflate'
import {
  defaultEstimation,
  estimateWeight,
  metricsFor3MF,
  metricsForSTL,
  parseSTL,
  trianglesFor3MF,
  type EstimationSettings,
  type WeightEstimate,
} from './mesh'
import { forEachTag, parseAttrs } from './xml'

export interface ImportedFilament {
  type: string | null
  colorHex: string | null
  grams: number
}

/** Estimativas de uma mesa gravadas pelo fatiador. */
export interface ImportedPlate {
  index: number
  weightGrams: number | null
  durationSeconds: number | null
  filaments: ImportedFilament[]
}

/** Impressora e perfil para os quais o projeto foi configurado no fatiador. */
export interface ImportedPrinter {
  model: string | null
  profile: string | null
  nozzleDiameter: string | null
  layerHeight: string | null
  printProfile: string | null
}

export interface ImportedModel {
  name: string
  weightGrams: number | null
  durationSeconds: number | null
  /** Todas as mesas fatiadas do arquivo (vazio em STL ou 3MF sem fatiamento). */
  plates: ImportedPlate[]
  /** Peso estimado pelo volume da malha (só quando o arquivo não traz o do fatiador). Aproximação. */
  estimatedWeight: WeightEstimate | null
  /** Impressora configurada no projeto (null em STL ou quando o 3MF não traz as configurações). */
  printer: ImportedPrinter | null
}

const MAX_SLICE_INFO = 1024 * 1024
const MAX_SETTINGS = 8 * 1024 * 1024
const MAX_MODEL = 300 * 1024 * 1024
const INVALID_3MF = 'Não foi possível ler este arquivo 3MF.'
const INVALID_STL = 'O arquivo STL está vazio ou inválido.'

/** Lê o arquivo escolhido pela pessoa (botão "Importar STL ou 3MF"). */
export async function importModelFile(file: File): Promise<ImportedModel> {
  return importModelBytes(file.name, new Uint8Array(await file.arrayBuffer()))
}

const empty = (name: string): ImportedModel => ({
  name,
  weightGrams: null,
  durationSeconds: null,
  plates: [],
  estimatedWeight: null,
  printer: null,
})

/**
 * Lê o nome do modelo e, em 3MF fatiado (Bambu/Orca/Creality), o peso e o tempo gravados pelo fatiador.
 * Sem esses dados, estima o peso pelo volume da malha.
 */
export function importModelBytes(fileName: string, data: Uint8Array): ImportedModel {
  const name = fileName.replace(/^.*[\\/]/, '').replace(/\.[^.]+$/, '')
  const extension = fileName.split('.').pop()?.toLowerCase()
  if (extension === 'stl') {
    validateSTL(data)
    const metrics = metricsForSTL(data)
    const grams = metrics ? estimateWeight(metrics, defaultEstimation()) : null
    return { ...empty(name), estimatedWeight: grams ? { grams, pieces: 1 } : null }
  }
  if (extension === '3mf') return import3MF(data, name)
  throw new Error('Escolha um arquivo STL ou 3MF.')
}

export function validateSTL(data: Uint8Array) {
  if (data.length === 0) throw new Error(INVALID_STL)
  const head = new TextDecoder().decode(data.subarray(0, Math.min(data.length, 1024))).trim().toLowerCase()
  if (head.startsWith('solid') && new TextDecoder().decode(data).toLowerCase().includes('facet')) return
  if (data.length < 84) throw new Error(INVALID_STL)
  const triangles = new DataView(data.buffer, data.byteOffset + 80, 4).getUint32(0, true)
  if (triangles === 0 || 84 + triangles * 50 !== data.length) throw new Error(INVALID_STL)
}

/** Nomes das entradas do zip e o conteúdo das que passarem no filtro. */
export function readZip(data: Uint8Array, wanted: (lowerName: string, size: number) => boolean) {
  const entries: string[] = []
  let files: Record<string, Uint8Array>
  try {
    files = unzipSync(data, {
      filter: (f) => {
        entries.push(f.name)
        return wanted(f.name.toLowerCase(), f.originalSize)
      },
    })
  } catch {
    throw new Error(INVALID_3MF)
  }
  return { entries, files }
}

export function import3MF(data: Uint8Array, name: string): ImportedModel {
  const { entries, files } = readZip(
    data,
    (n, size) =>
      (n === 'metadata/slice_info.config' && size <= MAX_SLICE_INFO) ||
      (n === 'metadata/project_settings.config' && size <= MAX_SETTINGS),
  )
  if (!entries.some((e) => e.toLowerCase() === '3d/3dmodel.model')) throw new Error(INVALID_3MF)

  const byName = (lower: string) => Object.entries(files).find(([k]) => k.toLowerCase() === lower)?.[1]
  const decoder = new TextDecoder()
  const sliceInfo = byName('metadata/slice_info.config')
  const settingsRaw = byName('metadata/project_settings.config')
  const settingsJSON = settingsRaw ? parseJSON(decoder.decode(settingsRaw)) : null

  const model = empty(name)
  if (sliceInfo) {
    const plates = parsePlates(decoder.decode(sliceInfo))
    model.plates = plates
    // Com mais de uma mesa fatiada não dá para saber qual vale; a escolha fica com quem usa.
    if (plates.length === 1) {
      model.weightGrams = plates[0].weightGrams
      model.durationSeconds = plates[0].durationSeconds
    }
  }
  if (settingsJSON) model.printer = printerFrom(settingsJSON)

  const hasWeight = model.weightGrams !== null || model.plates.some((p) => p.weightGrams !== null)
  if (!hasWeight) {
    try {
      const { files: models } = readZip(data, (n, size) => n.endsWith('.model') && size <= MAX_MODEL)
      const found = metricsFor3MF(models)
      const grams = found ? estimateWeight(found.metrics, settingsJSON ? estimationFrom(settingsJSON) : defaultEstimation()) : null
      if (found && grams) model.estimatedWeight = { grams, pieces: found.pieces }
    } catch {
      // Sem malha legível: fica sem estimativa.
    }
  }
  return model
}

/** Mesas fatiadas (com tempo previsto) de um slice_info.config. */
export function parsePlates(xml: string): ImportedPlate[] {
  interface Parsed {
    index: number | null
    prediction: number | null
    filaments: ImportedFilament[]
    byId: Map<string, number>
  }
  const parsed: Parsed[] = []
  let current: Parsed | null = null
  const decimal = (v: string | undefined) => {
    const n = v === undefined || v.trim() === '' ? NaN : Number(v)
    return Number.isFinite(n) ? n : null
  }
  forEachTag(xml, (name, attrsText, kind) => {
    if (kind === 'close') {
      if (name === 'plate') current = null
      return
    }
    if (name === 'plate') {
      current = { index: null, prediction: null, filaments: [], byId: new Map() }
      parsed.push(current)
      if (kind === 'self') current = null
    } else if (name === 'metadata' && current) {
      const a = parseAttrs(attrsText)
      const key = a.key?.toLowerCase()
      if (key === 'prediction') {
        const v = decimal(a.value)
        if (v !== null && v > 0) current.prediction = v
      } else if (key === 'index') {
        const v = decimal(a.value)
        if (v !== null && Number.isInteger(v)) current.index = v
      }
    } else if (name === 'filament' && current) {
      const a = parseAttrs(attrsText)
      const grams = decimal(a.used_g)
      if (a.id === undefined || grams === null || grams <= 0) return
      current.byId.set(a.id, grams)
      current.filaments.push({ type: a.type || null, colorHex: a.color || null, grams })
    }
  })
  return parsed
    .filter((p) => (p.prediction ?? 0) > 0)
    .map((p, offset) => {
      const weight = [...p.byId.values()].reduce((s, g) => s + g, 0)
      return {
        index: p.index ?? offset + 1,
        weightGrams: weight > 0 ? weight : null,
        durationSeconds: p.prediction,
        filaments: p.filaments,
      }
    })
}

/** Peso e tempo quando há uma única mesa fatiada. */
export function parseSliceInfo(xml: string): { weightGrams: number | null; durationSeconds: number | null } {
  const plates = parsePlates(xml)
  return plates.length === 1
    ? { weightGrams: plates[0].weightGrams, durationSeconds: plates[0].durationSeconds }
    : { weightGrams: null, durationSeconds: null }
}

function parseJSON(text: string): Record<string, unknown> | null {
  try {
    const value = JSON.parse(text)
    return value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : null
  } catch {
    return null
  }
}

/** Impressora, bico, camada e perfil de project_settings.config (Bambu Studio, Orca, Creality Print). */
export function printerFrom(json: Record<string, unknown>): ImportedPrinter | null {
  const text = (key: string): string | null => {
    const raw = json[key]
    const value = typeof raw === 'string' ? raw : Array.isArray(raw) && typeof raw[0] === 'string' ? raw[0] : null
    const trimmed = value?.trim()
    return trimmed ? trimmed : null
  }
  const printer: ImportedPrinter = {
    model: text('printer_model'),
    profile: text('printer_settings_id'),
    nozzleDiameter: text('nozzle_diameter'),
    layerHeight: text('layer_height'),
    printProfile: text('print_settings_id'),
  }
  return Object.values(printer).every((v) => v === null) ? null : printer
}

/** Densidade, preenchimento e paredes gravados no projeto (Bambu/Orca/Prusa). */
export function estimationFrom(json: Record<string, unknown>): EstimationSettings {
  const settings = defaultEstimation()
  const number = (value: unknown): number | null => {
    if (typeof value === 'string') {
      const n = Number(value.replace(/[% ]/g, ''))
      return Number.isFinite(n) ? n : null
    }
    return typeof value === 'number' ? value : null
  }
  const density = Array.isArray(json.filament_density) ? number(json.filament_density[0]) : null
  if (density !== null && density > 0.5 && density < 5) settings.densityGramsPerCm3 = density
  const infill = number(json.sparse_infill_density)
  if (infill !== null && infill >= 0 && infill <= 100) settings.infillFraction = infill / 100
  const loops = number(json.wall_loops)
  if (loops !== null && loops >= 1 && loops <= 20) settings.wallThicknessMM = Math.max(0.8, loops * 0.45)
  return settings
}

/** Nome, peso e tempo da peça a partir do que o arquivo traz; usa o peso estimado se faltar o do fatiador. */
export function jobPatchFromImport(data: ImportedModel): {
  name: string
  partWeight: number
  printHours: number
  printMinutes: number
} {
  const seconds = data.durationSeconds && data.durationSeconds > 0 ? data.durationSeconds : 0
  const minutes = seconds / 60
  const estimated = data.estimatedWeight ? Math.round(data.estimatedWeight.grams * 10) / 10 : 0
  return {
    name: data.name,
    partWeight: data.weightGrams ?? estimated,
    printHours: Math.floor(minutes / 60),
    printMinutes: Math.round((minutes % 60) * 100) / 100,
  }
}

/** Mesma importação, usando só a mesa escolhida (3MF com várias mesas fatiadas). */
export function selectPlate(data: ImportedModel, plate: ImportedPlate): ImportedModel {
  return { ...data, weightGrams: plate.weightGrams, durationSeconds: plate.durationSeconds }
}

/** Imagens que o fatiador grava dentro do 3MF, da mais bonita (capa) para a mais técnica. */
const EMBEDDED_IMAGES = [
  'auxiliaries/.thumbnails/thumbnail_middle.png',
  'auxiliaries/.thumbnails/thumbnail_3mf.png',
  'metadata/thumbnail.png',
  'thumbnails/thumbnail.png',
  'metadata/plate_1.png',
  'metadata/top_1.png',
]

/** Imagem embutida no 3MF (capa); null se não houver. */
export function embeddedImage3MF(data: Uint8Array): Uint8Array | null {
  try {
    const { files } = readZip(data, (n, size) => EMBEDDED_IMAGES.includes(n) && size <= 12 * 1024 * 1024)
    const lower = new Map(Object.entries(files).map(([k, v]) => [k.toLowerCase(), v]))
    for (const candidate of EMBEDDED_IMAGES) {
      const bytes = lower.get(candidate)
      if (bytes && bytes.length > 8) return bytes
    }
  } catch {
    // Arquivo ilegível: sem imagem embutida.
  }
  return null
}

/** Triângulos do modelo (STL ou 3MF) para gerar uma miniatura quando não há imagem embutida. */
export function modelTriangles(fileName: string, data: Uint8Array): Float32Array | null {
  const extension = fileName.split('.').pop()?.toLowerCase()
  if (extension === 'stl') return parseSTL(data)
  if (extension !== '3mf') return null
  try {
    return trianglesFor3MF(readZip(data, (n, size) => n.endsWith('.model') && size <= MAX_MODEL).files)
  } catch {
    return null
  }
}
