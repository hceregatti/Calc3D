/**
 * Motor de cálculo de custo e preço de impressão 3D (tradução do Calc3DCore em Swift).
 *
 * Fórmulas:
 * - Material     = peso × (1 + desperdício) × preço do rolo ÷ peso do rolo
 * - Energia      = W ÷ 1000 × horas × tarifa
 * - Depreciação  = (preço − revenda) ÷ vida útil × horas
 * - Manutenção   = manutenção anual ÷ horas/ano × horas
 * - Custos fixos = fixos mensais ÷ horas/mês × horas
 * - Falhas       = (material + energia + máquina + fixos) × f ÷ (1 − f)
 * - Mão de obra  = (preparação + pós) ÷ 60 × valor/h
 * - Preço        = (custo/peça + taxa fixa) ÷ (1 − margem − impostos − taxa %)
 */

/** Parâmetros que mudam pouco, configurados uma vez e usados em todas as impressões. */
export interface ShopSettings {
  spoolPrice: number
  spoolWeight: number
  powerWatts: number
  energyTariff: number
  printerPrice: number
  resaleValue: number
  lifetimeHours: number
  maintenancePerYear: number
  hoursPerYear: number
  laborRate: number
  packagingPerPart: number
  fixedCostsPerMonth: number
  hoursPerMonth: number
  failureRatePercent: number
  taxPercent: number
  marketplaceFeePercent: number
  fixedFeePerSale: number
}

export const defaultSettings: ShopSettings = {
  spoolPrice: 120,
  spoolWeight: 1000,
  powerWatts: 150,
  energyTariff: 1.05,
  printerPrice: 3500,
  resaleValue: 700,
  lifetimeHours: 5000,
  maintenancePerYear: 400,
  hoursPerYear: 1500,
  laborRate: 30,
  packagingPerPart: 3,
  fixedCostsPerMonth: 150,
  hoursPerMonth: 125,
  failureRatePercent: 10,
  taxPercent: 6,
  marketplaceFeePercent: 14,
  fixedFeePerSale: 4,
}

/** Dados de uma impressão (normalmente do fatiador). Peso e tempo são da mesa inteira. */
export interface PrintJob {
  name: string
  partWeight: number
  wastePercent: number
  printHours: number
  printMinutes: number
  partsPerPlate: number
  setupMinutes: number
  postProcessingMinutes: number
  consumablesPerPlate: number
  marginPercent: number
}

export const defaultJob: PrintJob = {
  name: '',
  partWeight: 85,
  wastePercent: 5,
  printHours: 6,
  printMinutes: 30,
  partsPerPlate: 1,
  setupMinutes: 15,
  postProcessingMinutes: 20,
  consumablesPerPlate: 2,
  marginPercent: 40,
}

export const MAX_FAILURE_RATE = 0.9

export const nonNegative = (v: number) => (Number.isFinite(v) ? Math.max(v, 0) : 0)
const atLeastOne = (v: number) => (Number.isFinite(v) ? Math.max(v, 1) : 1)

export function totalPrintHours(job: PrintJob) {
  return nonNegative(job.printHours) + nonNegative(job.printMinutes) / 60
}

/** Custos por hora derivados dos parâmetros fixos. */
export function derived(s: ShopSettings) {
  const filamentPricePerGram = nonNegative(s.spoolPrice) / atLeastOne(s.spoolWeight)
  const energyCostPerHour = (nonNegative(s.powerWatts) / 1000) * nonNegative(s.energyTariff)
  const depreciationPerHour = nonNegative(s.printerPrice - s.resaleValue) / atLeastOne(s.lifetimeHours)
  const maintenancePerHour = nonNegative(s.maintenancePerYear) / atLeastOne(s.hoursPerYear)
  const overheadPerHour = nonNegative(s.fixedCostsPerMonth) / atLeastOne(s.hoursPerMonth)
  return {
    filamentPricePerGram,
    energyCostPerHour,
    depreciationPerHour,
    maintenancePerHour,
    overheadPerHour,
    machineCostPerHour: energyCostPerHour + depreciationPerHour + maintenancePerHour + overheadPerHour,
    failureRate: Math.min(nonNegative(s.failureRatePercent) / 100, MAX_FAILURE_RATE),
  }
}

export type CostCategory =
  | 'filament'
  | 'energy'
  | 'depreciation'
  | 'maintenance'
  | 'overhead'
  | 'failures'
  | 'labor'
  | 'supplies'

export const CATEGORIES: { id: CostCategory; title: string; color: string }[] = [
  { id: 'filament', title: 'Filamento', color: 'var(--c-chart-1)' },
  { id: 'energy', title: 'Energia', color: 'var(--c-chart-7)' },
  { id: 'depreciation', title: 'Depreciação', color: 'var(--c-chart-4)' },
  { id: 'maintenance', title: 'Manutenção', color: 'var(--c-chart-8)' },
  { id: 'overhead', title: 'Custos fixos', color: 'var(--c-chart-5)' },
  { id: 'failures', title: 'Perdas por falha', color: 'var(--c-chart-6)' },
  { id: 'labor', title: 'Mão de obra', color: 'var(--c-chart-2)' },
  { id: 'supplies', title: 'Insumos + embalagem', color: 'var(--c-chart-3)' },
]

export const PRICING_ERROR = 'Margem + impostos + taxas somam 100% ou mais. Reduza algum deles.'

/** Resultado de um cálculo. Valores por peça, na ordem de CATEGORIES. */
export interface CostResult {
  items: { category: CostCategory; amount: number }[]
  partsPerPlate: number
  printHours: number
  marginPercent: number
  /** Preço sugerido por peça, ou null quando os percentuais somam 100% ou mais. */
  suggestedPrice: number | null
}

export const unitCost = (r: CostResult) => r.items.reduce((sum, i) => sum + i.amount, 0)
export const plateCost = (r: CostResult) => unitCost(r) * r.partsPerPlate
export const amountFor = (r: CostResult, c: CostCategory) => r.items.find((i) => i.category === c)?.amount ?? 0
export const shareOf = (r: CostResult, c: CostCategory) => {
  const total = unitCost(r)
  return total > 0 ? amountFor(r, c) / total : 0
}
export const profitPerPart = (r: CostResult) =>
  r.suggestedPrice === null ? null : (r.suggestedPrice * r.marginPercent) / 100
export const profitPerMachineHour = (r: CostResult) => {
  const profit = profitPerPart(r)
  return profit === null || r.printHours <= 0 ? null : (profit * r.partsPerPlate) / r.printHours
}
export const canPrice = (r: CostResult) =>
  r.suggestedPrice !== null && Number.isFinite(r.suggestedPrice) && r.suggestedPrice >= 0

export function calculate(s: ShopSettings, job: PrintJob): CostResult {
  const d = derived(s)
  const hours = totalPrintHours(job)
  const parts = Number.isFinite(job.partsPerPlate) ? Math.max(Math.floor(job.partsPerPlate), 1) : 1
  const f = d.failureRate

  const filament = nonNegative(job.partWeight) * (1 + nonNegative(job.wastePercent) / 100) * d.filamentPricePerGram
  const energy = d.energyCostPerHour * hours
  const depreciation = d.depreciationPerHour * hours
  const maintenance = d.maintenancePerHour * hours
  const overhead = d.overheadPerHour * hours

  // A falha refaz o trabalho da máquina e o material; o pós-processamento só acontece na peça boa.
  const production = filament + energy + depreciation + maintenance + overhead
  const failures = (production * f) / (1 - f)

  const labor = ((nonNegative(job.setupMinutes) + nonNegative(job.postProcessingMinutes)) / 60) * nonNegative(s.laborRate)
  const supplies = nonNegative(job.consumablesPerPlate) + nonNegative(s.packagingPerPart) * parts

  const plate: Record<CostCategory, number> = {
    filament,
    energy,
    depreciation,
    maintenance,
    overhead,
    failures,
    labor,
    supplies,
  }
  const items = CATEGORIES.map((c) => ({ category: c.id, amount: plate[c.id] / parts }))
  const cost = items.reduce((sum, i) => sum + i.amount, 0)

  const margin = nonNegative(job.marginPercent)
  const percentages = (margin + nonNegative(s.taxPercent) + nonNegative(s.marketplaceFeePercent)) / 100
  const suggestedPrice = percentages >= 1 ? null : (cost + nonNegative(s.fixedFeePerSale)) / (1 - percentages)

  return { items, partsPerPlate: parts, printHours: hours, marginPercent: margin, suggestedPrice }
}

// Formatação em pt-BR

const currencyFormat = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' })
export const brl = (v: number) => currencyFormat.format(Number.isFinite(v) ? v : 0)
export const number = (v: number, maxFraction = 2) =>
  v.toLocaleString('pt-BR', { maximumFractionDigits: maxFraction })
export const percent = (fraction: number, digits = 1) =>
  fraction.toLocaleString('pt-BR', { style: 'percent', maximumFractionDigits: digits })

/** Texto do orçamento para copiar e colar (WhatsApp, e-mail etc.). */
export function quoteSummary(r: CostResult, job: PrintJob): string {
  const name = job.name.trim()
  const title = name ? `Orçamento: ${name}` : 'Orçamento impressão 3D'
  const lines = [`${title}: ${r.partsPerPlate} peça(s), ${number(r.printHours)} h, ${number(job.partWeight, 3)} g`]
  for (const item of r.items) {
    const category = CATEGORIES.find((c) => c.id === item.category)!
    lines.push(`• ${category.title}: ${brl(item.amount)}`)
  }
  lines.push(`Custo por peça: ${brl(unitCost(r))}`)
  lines.push(
    r.suggestedPrice === null
      ? `Preço sugerido: indisponível (${PRICING_ERROR})`
      : `Preço sugerido: ${brl(r.suggestedPrice)} (margem ${Math.trunc(r.marginPercent)}%)`,
  )
  return lines.join('\n')
}
