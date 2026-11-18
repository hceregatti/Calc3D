import type { PrintJob } from './calculator'
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

// MARK: - Consumo e baixa de estoque

/** Uma baixa registrada no estoque de um rolo, guardada no orçamento que a gerou. */
export interface StockDeduction {
  filamentId: string
  filamentName: string
  /** Quanto o orçamento precisava. */
  requestedGrams: number
  /** Quanto realmente saiu do rolo (limitado ao que restava); é o que o estorno devolve. */
  grams: number
  date: string
}

export interface UsageLine {
  filamentId: string | null
  filamentName: string
  gramsPerUnit: number | null
  quantity: number
}

export interface Requirement {
  filamentId: string
  filamentName: string
  grams: number
}

/** Gramas por unidade vendida: peso da mesa com desperdício ÷ peças da mesa. Null sem filamento da biblioteca. */
export function gramsPerUnit(job: PrintJob): number | null {
  if (!job.filamentId) return null
  const parts = Number.isFinite(job.partsPerPlate) ? Math.max(Math.floor(job.partsPerPlate), 1) : 1
  return (nonNegative(job.partWeight) * (1 + nonNegative(job.wastePercent) / 100)) / parts
}

/** Soma o consumo por rolo; itens sem filamento são ignorados. */
export function requirements(lines: UsageLine[]): Requirement[] {
  const byId = new Map<string, Requirement>()
  for (const l of lines) {
    if (!l.filamentId || l.gramsPerUnit === null) continue
    const entry = byId.get(l.filamentId) ?? { filamentId: l.filamentId, filamentName: l.filamentName, grams: 0 }
    entry.grams += nonNegative(l.gramsPerUnit) * Math.max(l.quantity, 0)
    byId.set(l.filamentId, entry)
  }
  return [...byId.values()].sort((a, b) => a.filamentName.localeCompare(b.filamentName, 'pt-BR'))
}

/** Quanto falta (g) para atender o consumo; 0 se o rolo dá conta. */
export const shortage = (required: number, available: number) => Math.max(required - nonNegative(available), 0)

/** Desconta o consumo dos rolos (nunca abaixo de zero). Rolos removidos da biblioteca são ignorados. */
export function deduct(reqs: Requirement[], filaments: Filament[], date = new Date().toISOString()) {
  const deductions: StockDeduction[] = []
  const next = filaments.map((f) => ({ ...f }))
  for (const need of reqs) {
    const f = next.find((x) => x.id === need.filamentId)
    if (!f) continue
    const available = nonNegative(f.remainingWeight)
    const taken = Math.min(need.grams, available)
    f.remainingWeight = available - taken
    deductions.push({ filamentId: f.id, filamentName: filamentDisplayName(f), requestedGrams: need.grams, grams: taken, date })
  }
  return { filaments: next, deductions }
}

/** Devolve aos rolos exatamente o que as baixas retiraram. */
export function revert(deductions: StockDeduction[], filaments: Filament[]): Filament[] {
  const next = filaments.map((f) => ({ ...f }))
  for (const d of deductions) {
    const f = next.find((x) => x.id === d.filamentId)
    if (f) f.remainingWeight = Math.min(nonNegative(f.remainingWeight) + d.grams, Math.max(f.netWeight, f.remainingWeight))
  }
  return next
}

/** True quando o consumo atual difere do que foi baixado (orçamento editado depois da baixa). */
export function usageChanged(deductions: StockDeduction[], reqs: Requirement[]): boolean {
  const before = new Map<string, number>()
  for (const d of deductions) before.set(d.filamentId, (before.get(d.filamentId) ?? 0) + d.requestedGrams)
  const now = new Map(reqs.map((r) => [r.filamentId, r.grams]))
  if (before.size !== now.size) return true
  return [...now].some(([id, g]) => !before.has(id) || Math.abs(g - before.get(id)!) > 0.0001)
}

/** Rolo com pouco material (15% ou menos). */
export const isRunningLow = (f: Filament) => remainingFraction(f) <= 0.15
