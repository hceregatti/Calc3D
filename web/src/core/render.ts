/**
 * Miniatura de um modelo sem imagem embutida (STL, ou 3MF sem capa): projeção isométrica com
 * sombreamento simples, ordenada por profundidade. Equivale ao que o Quick Look faz no macOS.
 */
const MAX_TRIANGLES = 40_000

export interface Projected {
  /** x,y de cada vértice (6 números por triângulo) já em pixels. */
  points: Float32Array
  /** brilho 0..1 e profundidade de cada triângulo, na ordem de desenho (do fundo para a frente). */
  shade: Float32Array
  order: number[]
}

/** Calcula a projeção; separado do canvas para poder ser testado. */
export function project(triangles: ArrayLike<number>, size: number): Projected | null {
  const total = Math.floor(triangles.length / 9)
  if (total === 0) return null
  const step = Math.max(1, Math.ceil(total / MAX_TRIANGLES))
  const count = Math.ceil(total / step)

  // Gira: Z para cima, câmera a 35° de azimute e 30° de elevação.
  const az = (-35 * Math.PI) / 180
  const el = (-60 * Math.PI) / 180
  const ca = Math.cos(az), sa = Math.sin(az), ce = Math.cos(el), se = Math.sin(el)
  const rot = (x: number, y: number, z: number): [number, number, number] => {
    const x1 = x * ca - y * sa
    const y1 = x * sa + y * ca
    return [x1, y1 * ce - z * se, y1 * se + z * ce]
  }

  const rotated = new Float32Array(count * 9)
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
  for (let n = 0, t = 0; t < total; t += step, n++) {
    for (let v = 0; v < 3; v++) {
      const [x, y, z] = rot(triangles[t * 9 + v * 3], triangles[t * 9 + v * 3 + 1], triangles[t * 9 + v * 3 + 2])
      rotated[n * 9 + v * 3] = x
      rotated[n * 9 + v * 3 + 1] = y
      rotated[n * 9 + v * 3 + 2] = z
      if (x < minX) minX = x
      if (x > maxX) maxX = x
      if (y < minY) minY = y
      if (y > maxY) maxY = y
    }
  }
  const span = Math.max(maxX - minX, maxY - minY)
  if (!(span > 0) || !Number.isFinite(span)) return null
  const margin = size * 0.08
  const scale = (size - margin * 2) / span
  const offX = (size - (maxX - minX) * scale) / 2 - minX * scale
  const offY = (size - (maxY - minY) * scale) / 2 - minY * scale

  const points = new Float32Array(count * 6)
  const shade = new Float32Array(count)
  const depth = new Float32Array(count)
  for (let n = 0; n < count; n++) {
    const b = n * 9
    for (let v = 0; v < 3; v++) {
      points[n * 6 + v * 2] = rotated[b + v * 3] * scale + offX
      // Y da tela cresce para baixo.
      points[n * 6 + v * 2 + 1] = size - (rotated[b + v * 3 + 1] * scale + offY)
    }
    const ux = rotated[b + 3] - rotated[b], uy = rotated[b + 4] - rotated[b + 1], uz = rotated[b + 5] - rotated[b + 2]
    const wx = rotated[b + 6] - rotated[b], wy = rotated[b + 7] - rotated[b + 1], wz = rotated[b + 8] - rotated[b + 2]
    let nx = uy * wz - uz * wy, ny = uz * wx - ux * wz, nz = ux * wy - uy * wx
    const len = Math.hypot(nx, ny, nz) || 1
    nx /= len; ny /= len; nz /= len
    // Luz vindo de cima-esquerda da câmera; aceita os dois sentidos da normal.
    shade[n] = 0.25 + 0.75 * Math.abs(nx * -0.4 + ny * 0.5 + nz * 0.77)
    depth[n] = (rotated[b + 2] + rotated[b + 5] + rotated[b + 8]) / 3
  }
  const order = Array.from({ length: count }, (_, i) => i).sort((a, b) => depth[a] - depth[b])
  return { points, shade, order }
}

/** PNG da miniatura; null se o ambiente não tiver canvas. */
export async function renderThumbnail(triangles: ArrayLike<number>, size = 384): Promise<Blob | null> {
  if (typeof document === 'undefined') return null
  const projected = project(triangles, size)
  if (!projected) return null
  const canvas = document.createElement('canvas')
  canvas.width = canvas.height = size
  const ctx = canvas.getContext('2d')
  if (!ctx) return null
  const { points, shade, order } = projected
  for (const n of order) {
    const g = Math.round(70 + shade[n] * 150)
    // Tom azulado, como o modelo cinza do Quick Look.
    const color = `rgb(${g}, ${Math.min(255, g + 8)}, ${Math.min(255, g + 20)})`
    ctx.fillStyle = color
    ctx.strokeStyle = color
    ctx.lineWidth = 0.6
    ctx.beginPath()
    ctx.moveTo(points[n * 6], points[n * 6 + 1])
    ctx.lineTo(points[n * 6 + 2], points[n * 6 + 3])
    ctx.lineTo(points[n * 6 + 4], points[n * 6 + 5])
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
  }
  return new Promise((resolve) => canvas.toBlob((blob) => resolve(blob), 'image/png'))
}
