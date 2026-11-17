import { uid, withDefaults } from './models'

export const MATERIALS = ['PLA', 'PLA+', 'PETG', 'ABS', 'ASA', 'TPU', 'Nylon (PA)', 'PC', 'PVA', 'Outro'] as const
export type Material = (typeof MATERIALS)[number]

/** Temperatura de bico (mín–máx, °C), mesa (°C) e densidade (g/cm³) típicas; cada marca varia. */
export const TYPICAL_PROFILE: Record<Material, { nozzleTempMin: number; nozzleTempMax: number; bedTemp: number; density: number }> = {
  PLA: { nozzleTempMin: 190, nozzleTempMax: 220, bedTemp: 60, density: 1.24 },
  'PLA+': { nozzleTempMin: 200, nozzleTempMax: 230, bedTemp: 60, density: 1.24 },
  PETG: { nozzleTempMin: 220, nozzleTempMax: 250, bedTemp: 80, density: 1.27 },
  ABS: { nozzleTempMin: 230, nozzleTempMax: 260, bedTemp: 100, density: 1.04 },
  ASA: { nozzleTempMin: 240, nozzleTempMax: 270, bedTemp: 100, density: 1.07 },
  TPU: { nozzleTempMin: 210, nozzleTempMax: 240, bedTemp: 50, density: 1.21 },
  'Nylon (PA)': { nozzleTempMin: 250, nozzleTempMax: 285, bedTemp: 80, density: 1.14 },
  PC: { nozzleTempMin: 260, nozzleTempMax: 300, bedTemp: 110, density: 1.2 },
  PVA: { nozzleTempMin: 190, nozzleTempMax: 210, bedTemp: 60, density: 1.23 },
  Outro: { nozzleTempMin: 200, nozzleTempMax: 230, bedTemp: 60, density: 1.24 },
}

/** Um rolo de filamento da biblioteca. */
export interface Filament {
  id: string
  brand: string
  /** Linha/nome do produto (ex.: Silk, Basic). */
  name: string
  material: Material
  colorName: string
  /** Cor de exibição, "#RRGGBB". */
  colorHex: string
  /** Diâmetro do fio (mm). */
  diameter: number
  /** Peso líquido do rolo (g). */
  netWeight: number
  /** Quanto resta no rolo (g). */
  remainingWeight: number
  /** Preço pago pelo rolo. */
  price: number
  nozzleTempMin: number
  nozzleTempMax: number
  bedTemp: number
  /** g/cm³ */
  density: number
  purchaseUrl: string
  store: string
  notes: string
  createdAt: string
}

export function newFilament(material: Material = 'PLA'): Filament {
  return {
    id: uid(),
    brand: '',
    name: '',
    material,
    colorName: '',
    colorHex: '#9a9994',
    diameter: 1.75,
    netWeight: 1000,
    remainingWeight: 1000,
    price: 0,
    ...TYPICAL_PROFILE[material],
    purchaseUrl: '',
    store: '',
    notes: '',
    createdAt: new Date().toISOString(),
  }
}

/** Completa dados salvos com os padrões atuais, para versões futuras não quebrarem a biblioteca. */
export function normalizeFilament(raw: Filament): Filament {
  const base = withDefaults(newFilament(), raw)
  return { ...base, id: raw.id ?? base.id, material: MATERIALS.includes(raw.material) ? raw.material : 'Outro' }
}

const nonNegative = (v: number) => (Number.isFinite(v) ? Math.max(v, 0) : 0)

export const filamentPricePerGram = (f: Filament) => nonNegative(f.price) / Math.max(Number.isFinite(f.netWeight) ? f.netWeight : 1, 1)

/** Fração restante do rolo (0…1). */
export const remainingFraction = (f: Filament) =>
  Math.min(nonNegative(f.remainingWeight) / Math.max(Number.isFinite(f.netWeight) ? f.netWeight : 1, 1), 1)

/** "Marca Linha Material · Cor". */
export function filamentDisplayName(f: Filament): string {
  const title = [f.brand, f.name, f.material].map((p) => p.trim()).filter(Boolean).join(' ')
  const color = f.colorName.trim()
  return color ? `${title} · ${color}` : title
}

/** Link de compra válido (somente http/https). */
export function purchaseLink(f: Filament): string | null {
  let text = f.purchaseUrl.trim()
  if (!text) return null
  if (!text.includes('://')) text = `https://${text}`
  try {
    const url = new URL(text)
    return ['http:', 'https:'].includes(url.protocol) && url.hostname.includes('.') ? url.toString() : null
  } catch {
    return null
  }
}

/** Pesquisa de compra na web (Google Shopping) para este filamento. */
export function searchUrl(f: Filament): string {
  const weight = f.netWeight >= 1000 && f.netWeight % 1000 === 0 ? `${f.netWeight / 1000}kg` : `${Math.round(f.netWeight)}g`
  const terms = ['filamento', f.brand, f.name, f.material, f.colorName, `${String(f.diameter).replace('.', ',')}mm`, weight]
  const q = terms.map((t) => t.trim()).filter(Boolean).join(' ')
  return `https://www.google.com/search?${new URLSearchParams({ q, tbm: 'shop' })}`
}
