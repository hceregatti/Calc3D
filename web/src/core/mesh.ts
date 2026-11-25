import { forEachTag, parseAttrs } from './xml'

/** Volume (mm³) e área de superfície (mm²) de uma malha. */
export interface MeshMetrics {
  volume: number
  area: number
}

export const ZERO_METRICS: MeshMetrics = { volume: 0, area: 0 }
const add = (a: MeshMetrics, b: MeshMetrics): MeshMetrics => ({ volume: a.volume + b.volume, area: a.area + b.area })

/** Aplica o determinante de uma transformação: volume pelo fator, área por fator^(2/3). */
function scaled(m: MeshMetrics, volumeFactor: number): MeshMetrics {
  return { volume: m.volume * volumeFactor, area: m.area * Math.pow(volumeFactor, 2 / 3) }
}

/** Parâmetros do fatiador que influenciam o peso (lidos do projeto quando existem). */
export interface EstimationSettings {
  densityGramsPerCm3: number
  infillFraction: number
  wallThicknessMM: number
}

export const defaultEstimation = (): EstimationSettings => ({ densityGramsPerCm3: 1.24, infillFraction: 0.15, wallThicknessMM: 0.9 })

export interface WeightEstimate {
  grams: number
  pieces: number
}

/**
 * Estima o peso pelo volume: casca (paredes + topo/base) maciça mais o miolo com a densidade de
 * preenchimento. É uma aproximação; ignora suportes, brim, torre de limpeza e desperdício.
 */
export function estimateWeight(metrics: MeshMetrics, settings: EstimationSettings): number | null {
  if (!(metrics.volume > 0)) return null
  const shell = Math.min(metrics.volume, metrics.area * settings.wallThicknessMM)
  const inner = metrics.volume - shell
  const solidMM3 = shell + inner * settings.infillFraction
  const grams = (solidMM3 / 1000) * settings.densityGramsPerCm3
  return Number.isFinite(grams) && grams > 0 ? grams : null
}

// MARK: Geometria

/** Triângulos como [x1,y1,z1, x2,y2,z2, x3,y3,z3, ...]. */
export type Triangles = Float32Array | Float64Array | number[]

export function metricsOfTriangles(t: Triangles): MeshMetrics {
  let volume = 0
  let area = 0
  for (let i = 0; i + 8 < t.length; i += 9) {
    const ax = t[i], ay = t[i + 1], az = t[i + 2]
    const bx = t[i + 3], by = t[i + 4], bz = t[i + 5]
    const cx = t[i + 6], cy = t[i + 7], cz = t[i + 8]
    volume += (ax * (by * cz - bz * cy) + ay * (bz * cx - bx * cz) + az * (bx * cy - by * cx)) / 6
    const ux = bx - ax, uy = by - ay, uz = bz - az
    const vx = cx - ax, vy = cy - ay, vz = cz - az
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx
    area += 0.5 * Math.sqrt(nx * nx + ny * ny + nz * nz)
  }
  return { volume: Math.abs(volume), area }
}

// MARK: STL

const MAX_MODEL_BYTES = 300 * 1024 * 1024

/** Triângulos de um STL binário ou ASCII; null se não houver nenhum. */
export function parseSTL(data: Uint8Array): Float32Array | null {
  if (data.length > MAX_MODEL_BYTES) return null
  if (data.length >= 84) {
    const view = new DataView(data.buffer, data.byteOffset, data.byteLength)
    const count = view.getUint32(80, true)
    if (count > 0 && 84 + count * 50 === data.length) {
      const out = new Float32Array(count * 9)
      for (let i = 0; i < count; i++) {
        const base = 84 + i * 50 + 12
        for (let k = 0; k < 9; k++) out[i * 9 + k] = view.getFloat32(base + k * 4, true)
      }
      return out
    }
  }
  const text = new TextDecoder().decode(data)
  const numbers: number[] = []
  const re = /vertex\s+(\S+)\s+(\S+)\s+(\S+)/gi
  let m: RegExpExecArray | null
  while ((m = re.exec(text))) numbers.push(Number(m[1]), Number(m[2]), Number(m[3]))
  const usable = numbers.length - (numbers.length % 9)
  if (usable === 0 || numbers.slice(0, usable).some((n) => !Number.isFinite(n))) return null
  return Float32Array.from(numbers.slice(0, usable))
}

export function metricsForSTL(data: Uint8Array): MeshMetrics | null {
  const triangles = parseSTL(data)
  return triangles ? metricsOfTriangles(triangles) : null
}

// MARK: 3MF

/** Transformação 3MF: 12 números (3x3 + translação), em convenção de vetor-linha. */
type Matrix = number[]
const IDENTITY: Matrix = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]

function parseMatrix(text: string | undefined): Matrix {
  if (!text) return IDENTITY
  const m = text.split(/[\s,]+/).filter(Boolean).map(Number)
  return m.length >= 12 && m.every(Number.isFinite) ? m.slice(0, 12) : IDENTITY
}

function volumeFactor(m: Matrix): number {
  return Math.abs(m[0] * (m[4] * m[8] - m[5] * m[7]) - m[1] * (m[3] * m[8] - m[5] * m[6]) + m[2] * (m[3] * m[7] - m[4] * m[6]))
}

/** `a` aplicada primeiro, depois `b` (vetor-linha: v·A·B). */
function multiply(a: Matrix, b: Matrix): Matrix {
  const out = new Array<number>(12)
  for (let r = 0; r < 3; r++) {
    for (let c = 0; c < 3; c++) out[r * 3 + c] = a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c]
  }
  for (let c = 0; c < 3; c++) out[9 + c] = a[9] * b[c] + a[10] * b[3 + c] + a[11] * b[6 + c] + b[9 + c]
  return out
}

interface ModelObject {
  vertices: number[]
  indices: number[]
  hasMesh: boolean
  metrics: MeshMetrics | null
  components: { objectId: number; path: string | null; matrix: Matrix }[]
}
interface ModelFile {
  unitScale: number
  objects: Map<number, ModelObject>
  items: { objectId: number; matrix: Matrix }[]
}

const UNITS: Record<string, number> = { micron: 0.001, millimeter: 1, centimeter: 10, meter: 1000, inch: 25.4, foot: 304.8 }

export function parseModelXML(xml: string): ModelFile {
  const file: ModelFile = { unitScale: 1, objects: new Map(), items: [] }
  let current: ModelObject | null = null
  let currentId: number | null = null
  let currentIsModel = true
  let inMesh = false
  forEachTag(xml, (name, attrsText, kind) => {
    if (kind === 'close') {
      if (name === 'mesh' && current) {
        inMesh = false
        current.metrics = metricsOfTriangles(expand(current.vertices, current.indices))
      } else if (name === 'object') {
        if (currentId !== null && currentIsModel && current) file.objects.set(currentId, current)
        current = null
        currentId = null
      }
      return
    }
    switch (name) {
      case 'vertex': {
        if (!inMesh || !current) return
        const a = parseAttrs(attrsText)
        current.vertices.push(Number(a.x) || 0, Number(a.y) || 0, Number(a.z) || 0)
        return
      }
      case 'triangle': {
        if (!inMesh || !current) return
        const a = parseAttrs(attrsText)
        const i = Number(a.v1), j = Number(a.v2), k = Number(a.v3)
        const n = current.vertices.length / 3
        if ([i, j, k].every((v) => Number.isInteger(v) && v >= 0 && v < n)) current.indices.push(i, j, k)
        return
      }
      case 'model': {
        const unit = parseAttrs(attrsText).unit?.toLowerCase()
        file.unitScale = (unit && UNITS[unit]) || 1
        return
      }
      case 'object': {
        const a = parseAttrs(attrsText)
        currentId = a.id !== undefined && Number.isInteger(Number(a.id)) ? Number(a.id) : null
        currentIsModel = (a.type ?? 'model') === 'model'
        current = { vertices: [], indices: [], hasMesh: false, metrics: null, components: [] }
        return
      }
      case 'mesh':
        if (current) {
          inMesh = true
          current.hasMesh = true
        }
        return
      case 'component': {
        if (!current) return
        const a = parseAttrs(attrsText)
        const id = Number(a.objectid)
        if (Number.isInteger(id)) current.components.push({ objectId: id, path: a['p:path'] ?? null, matrix: parseMatrix(a.transform) })
        return
      }
      case 'item': {
        const a = parseAttrs(attrsText)
        const id = Number(a.objectid)
        if (Number.isInteger(id)) file.items.push({ objectId: id, matrix: parseMatrix(a.transform) })
      }
    }
  })
  return file
}

function expand(vertices: number[], indices: number[]): Float64Array {
  const out = new Float64Array(indices.length * 3)
  for (let i = 0; i < indices.length; i++) {
    out[i * 3] = vertices[indices[i] * 3]
    out[i * 3 + 1] = vertices[indices[i] * 3 + 1]
    out[i * 3 + 2] = vertices[indices[i] * 3 + 2]
  }
  return out
}

/** Arquivos .model do 3MF já lidos, indexados por caminho ("/3D/3dmodel.model"). */
export type ModelFiles = Map<string, ModelFile>

export function parseModelFiles(models: Record<string, Uint8Array>): { files: ModelFiles; mainPath: string } | null {
  const paths = Object.keys(models)
  const main = paths.find((p) => p.toLowerCase() === '3d/3dmodel.model')
  if (!main) return null
  const files: ModelFiles = new Map()
  const decoder = new TextDecoder()
  for (const path of paths) files.set('/' + path, parseModelXML(decoder.decode(models[path])))
  return { files, mainPath: '/' + main }
}

function resolveMetrics(objectId: number, path: string, files: ModelFiles, depth: number): MeshMetrics | null {
  const object = files.get(path)?.objects.get(objectId)
  if (!object || depth >= 8) return null
  if (object.hasMesh) return object.metrics
  let sum = ZERO_METRICS
  let found = false
  for (const c of object.components) {
    const m = resolveMetrics(c.objectId, c.path ?? path, files, depth + 1)
    if (m) {
      sum = add(sum, scaled(m, volumeFactor(c.matrix)))
      found = true
    }
  }
  return found ? sum : null
}

/** Soma o volume de todos os itens da mesa (build) do 3MF; null se não achar malha. */
export function metricsFor3MF(models: Record<string, Uint8Array>): { metrics: MeshMetrics; pieces: number } | null {
  const parsed = parseModelFiles(models)
  if (!parsed) return null
  const main = parsed.files.get(parsed.mainPath)
  if (!main || !main.items.length) return null
  let total = ZERO_METRICS
  let pieces = 0
  for (const item of main.items) {
    const m = resolveMetrics(item.objectId, parsed.mainPath, parsed.files, 0)
    if (!m) continue
    total = add(total, scaled(m, volumeFactor(item.matrix)))
    pieces++
  }
  if (!(total.volume > 0)) return null
  return { metrics: scaled(total, Math.pow(main.unitScale, 3)), pieces }
}

function collectTriangles(objectId: number, path: string, matrix: Matrix, files: ModelFiles, depth: number, out: number[]) {
  const object = files.get(path)?.objects.get(objectId)
  if (!object || depth >= 8) return
  if (object.hasMesh) {
    const { vertices, indices } = object
    for (const index of indices) {
      const x = vertices[index * 3], y = vertices[index * 3 + 1], z = vertices[index * 3 + 2]
      out.push(
        x * matrix[0] + y * matrix[3] + z * matrix[6] + matrix[9],
        x * matrix[1] + y * matrix[4] + z * matrix[7] + matrix[10],
        x * matrix[2] + y * matrix[5] + z * matrix[8] + matrix[11],
      )
    }
    return
  }
  for (const c of object.components) collectTriangles(c.objectId, c.path ?? path, multiply(c.matrix, matrix), files, depth + 1, out)
}

/** Triângulos de toda a mesa do 3MF, com as transformações aplicadas (para gerar a miniatura). */
export function trianglesFor3MF(models: Record<string, Uint8Array>): Float32Array | null {
  const parsed = parseModelFiles(models)
  const main = parsed && parsed.files.get(parsed.mainPath)
  if (!parsed || !main) return null
  const out: number[] = []
  for (const item of main.items) collectTriangles(item.objectId, parsed.mainPath, item.matrix, parsed.files, 0, out)
  return out.length ? Float32Array.from(out) : null
}
