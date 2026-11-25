import { zipSync, strToU8 } from 'fflate'
import { describe, expect, it } from 'vitest'
import { embeddedImage3MF, estimationFrom, import3MF, importModelBytes, jobPatchFromImport, parsePlates, printerFrom } from './importer'
import { estimateWeight, defaultEstimation, metricsOfTriangles, parseSTL } from './mesh'
import { project } from './render'

/** STL binário de um cubo de 10 mm de aresta. */
function cubeSTL(size = 10): Uint8Array {
  const v = [[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0], [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]].map((p) => p.map((c) => c * size))
  const f = [[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7], [0, 1, 5], [0, 5, 4], [1, 2, 6], [1, 6, 5], [2, 3, 7], [2, 7, 6], [3, 0, 4], [3, 4, 7]]
  const buf = new ArrayBuffer(84 + f.length * 50)
  const view = new DataView(buf)
  view.setUint32(80, f.length, true)
  f.forEach((tri, i) => {
    tri.forEach((vi, k) => v[vi].forEach((c, a) => view.setFloat32(84 + i * 50 + 12 + k * 12 + a * 4, c, true)))
  })
  return new Uint8Array(buf)
}

const model = (body: string, build = '<item objectid="1"/>', unit = 'millimeter') =>
  `<?xml version="1.0"?><model unit="${unit}" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02"><resources>${body}</resources><build>${build}</build></model>`

const cubeObject = (id: number, s = 10) =>
  `<object id="${id}" type="model"><mesh><vertices>` +
  [[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0], [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]].map(([x, y, z]) => `<vertex x="${x * s}" y="${y * s}" z="${z * s}"/>`).join('') +
  `</vertices><triangles>` +
  [[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7], [0, 1, 5], [0, 5, 4], [1, 2, 6], [1, 6, 5], [2, 3, 7], [2, 7, 6], [3, 0, 4], [3, 4, 7]].map(([a, b, c]) => `<triangle v1="${a}" v2="${b}" v3="${c}"/>`).join('') +
  `</triangles></mesh></object>`

const SLICE = `<config><plate><metadata key="index" value="1"/><metadata key="prediction" value="5400"/>
<filament id="1" type="PLA" color="#FF0000" used_g="10.0"/><filament id="2" type="PETG" color="#00FF00" used_g="2.5"/></plate></config>`

const zip3mf = (files: Record<string, string | Uint8Array>) =>
  zipSync(Object.fromEntries(Object.entries(files).map(([k, v]) => [k, typeof v === 'string' ? strToU8(v) : v])))

describe('malha', () => {
  it('calcula volume e área de um cubo', () => {
    const m = metricsOfTriangles(parseSTL(cubeSTL())!)
    expect(m.volume).toBeCloseTo(1000, 3)
    expect(m.area).toBeCloseTo(600, 3)
  })
  it('lê STL ASCII', () => {
    const text = 'solid x\n' + [[0, 0, 0], [10, 0, 0], [0, 10, 0]].map((v) => `vertex ${v.join(' ')}`).join('\n') + '\nendsolid'
    expect(parseSTL(new TextEncoder().encode(text))!.length).toBe(9)
  })
  it('estima o peso por casca + preenchimento (PLA 15%, parede 0,9 mm)', () => {
    // cubo 10 mm: casca = min(1000, 600*0.9)=540; miolo 460*0.15=69 → 609 mm³ → 0,609 cm³ × 1,24
    expect(estimateWeight({ volume: 1000, area: 600 }, defaultEstimation())).toBeCloseTo(0.755, 2)
    expect(estimateWeight({ volume: 0, area: 0 }, defaultEstimation())).toBeNull()
  })
})

describe('importação', () => {
  it('STL: sem peso do fatiador, estima pelo volume', () => {
    const data = importModelBytes('C:\\modelos\\cubo.stl', cubeSTL())
    expect(data.name).toBe('cubo')
    expect(data.weightGrams).toBeNull()
    expect(data.estimatedWeight?.grams).toBeGreaterThan(0)
    expect(jobPatchFromImport(data).partWeight).toBeCloseTo(0.8, 1)
  })
  it('STL inválido', () => {
    expect(() => importModelBytes('x.stl', new Uint8Array(10))).toThrow('STL')
    expect(() => importModelBytes('x.obj', new Uint8Array(10))).toThrow('STL ou 3MF')
  })
  it('3MF fatiado: peso, tempo, filamentos e impressora', () => {
    const data = importModelBytes('peça.3mf', zip3mf({
      '3D/3dmodel.model': model(cubeObject(1)),
      'Metadata/slice_info.config': SLICE,
      'Metadata/project_settings.config': JSON.stringify({ printer_model: 'Bambu Lab A1', nozzle_diameter: ['0.4'], layer_height: '0.2', print_settings_id: '0.20mm Standard' }),
    }))
    expect(data.weightGrams).toBeCloseTo(12.5)
    expect(data.durationSeconds).toBe(5400)
    expect(data.estimatedWeight).toBeNull()
    expect(data.plates[0].filaments.map((f) => f.type)).toEqual(['PLA', 'PETG'])
    expect(data.printer).toMatchObject({ model: 'Bambu Lab A1', nozzleDiameter: '0.4', layerHeight: '0.2', printProfile: '0.20mm Standard' })
    expect(jobPatchFromImport(data)).toEqual({ name: 'peça', partWeight: 12.5, printHours: 1, printMinutes: 30 })
  })
  it('3MF com várias mesas: não escolhe sozinho', () => {
    const two = `<config><plate><metadata key="index" value="1"/><metadata key="prediction" value="60"/><filament id="1" used_g="1"/></plate>
      <plate><metadata key="index" value="2"/><metadata key="prediction" value="120"/><filament id="1" used_g="2"/></plate></config>`
    const data = import3MF(zip3mf({ '3D/3dmodel.model': model(cubeObject(1)), 'Metadata/slice_info.config': two }), 'x')
    expect(data.plates.map((p) => p.index)).toEqual([1, 2])
    expect(data.weightGrams).toBeNull()
    expect(data.durationSeconds).toBeNull()
  })
  it('3MF sem fatiamento: estima pelo volume, com transformação e unidade', () => {
    const body = cubeObject(1)
    const scaled = model(body, '<item objectid="1" transform="2 0 0 0 2 0 0 0 2 0 0 0"/>')
    const base = import3MF(zip3mf({ '3D/3dmodel.model': model(body) }), 'x').estimatedWeight!
    const big = import3MF(zip3mf({ '3D/3dmodel.model': scaled }), 'x').estimatedWeight!
    expect(base.pieces).toBe(1)
    expect(big.grams).toBeGreaterThan(base.grams * 3) // 8× o volume, 4× a área
    const cm = import3MF(zip3mf({ '3D/3dmodel.model': model(body, '<item objectid="1"/>', 'centimeter') }), 'x').estimatedWeight!
    expect(cm.grams).toBeGreaterThan(base.grams * 100)
  })
  it('3MF com componentes em outro arquivo (p:path)', () => {
    const main = model('<object id="5" type="model"><components><component objectid="1" p:path="/3D/Objects/o.model" xmlns:p="x"/></components></object>', '<item objectid="5"/>')
    const data = import3MF(zip3mf({ '3D/3dmodel.model': main, '3D/Objects/o.model': model(cubeObject(1)) }), 'x')
    expect(data.estimatedWeight?.pieces).toBe(1)
    expect(data.estimatedWeight!.grams).toBeCloseTo(0.755, 2)
  })
  it('3MF inválido', () => {
    expect(() => import3MF(strToU8('não é zip'), 'x')).toThrow('3MF')
    expect(() => import3MF(zip3mf({ 'a.txt': 'x' }), 'x')).toThrow('3MF')
  })
  it('lê a configuração do projeto (densidade, preenchimento, paredes)', () => {
    expect(estimationFrom({ filament_density: ['1.27'], sparse_infill_density: '20%', wall_loops: '3' })).toEqual({
      densityGramsPerCm3: 1.27, infillFraction: 0.2, wallThicknessMM: 1.35,
    })
    expect(printerFrom({})).toBeNull()
  })
  it('imagem embutida: prefere a capa e ignora o resto', () => {
    const png = new Uint8Array([137, 80, 78, 71, 1, 2, 3, 4, 5])
    const other = new Uint8Array([9, 9, 9, 9, 9, 9, 9, 9, 9])
    const data = zip3mf({ '3D/3dmodel.model': model(''), 'Metadata/plate_1.png': other, 'Auxiliaries/.thumbnails/thumbnail_middle.png': png })
    expect(embeddedImage3MF(data)).toEqual(png)
    expect(embeddedImage3MF(zip3mf({ 'a.txt': 'x' }))).toBeNull()
  })
  it('slice_info lê mesas com tempo e ignora as sem estimativa', () => {
    expect(parsePlates('<config><plate><metadata key="prediction" value="0"/></plate></config>')).toEqual([])
  })
})

describe('miniatura', () => {
  it('projeta o modelo dentro do quadro, do fundo para a frente', () => {
    const p = project(parseSTL(cubeSTL())!, 200)!
    expect(p.order).toHaveLength(12)
    for (const c of p.points) expect(c).toBeGreaterThanOrEqual(0), expect(c).toBeLessThanOrEqual(200)
    expect(project([], 200)).toBeNull()
  })
})
