/**
 * Formatação e máscaras no padrão brasileiro (espelha Calc3DCore/Formatting.swift).
 * Números sempre como 7.000,00; a moeda e a unidade de peso vêm dos parâmetros fixos.
 */

export type CurrencyCode = 'BRL' | 'USD' | 'EUR' | 'GBP'
export type WeightUnitId = 'g' | 'kg' | 'oz' | 'lb'

export const CURRENCIES: Record<CurrencyCode, { symbol: string; title: string }> = {
  BRL: { symbol: 'R$', title: 'Real (R$)' },
  USD: { symbol: 'US$', title: 'Dólar americano (US$)' },
  EUR: { symbol: '€', title: 'Euro (€)' },
  GBP: { symbol: '£', title: 'Libra esterlina (£)' },
}

export const WEIGHT_UNITS: Record<WeightUnitId, { title: string; grams: number; digits: number; bulk: WeightUnitId }> = {
  g: { title: 'Grama (g)', grams: 1, digits: 2, bulk: 'kg' },
  kg: { title: 'Quilograma (kg)', grams: 1000, digits: 3, bulk: 'kg' },
  oz: { title: 'Onça (oz)', grams: 28.349523125, digits: 2, bulk: 'lb' },
  lb: { title: 'Libra (lb)', grams: 453.59237, digits: 3, bulk: 'lb' },
}

export const isCurrency = (v: unknown): v is CurrencyCode => typeof v === 'string' && v in CURRENCIES
export const isWeightUnit = (v: unknown): v is WeightUnitId => typeof v === 'string' && v in WEIGHT_UNITS

/** Preferências globais de exibição, sincronizadas com os parâmetros fixos. */
export const display: { currency: CurrencyCode; weightUnit: WeightUnitId } = { currency: 'BRL', weightUnit: 'g' }

/** Garante moeda e unidade válidas (dados antigos ou backups editados à mão). */
export function withValidDisplay<T extends { currency: CurrencyCode; weightUnit: WeightUnitId }>(s: T): T {
  return {
    ...s,
    currency: isCurrency(s.currency) ? s.currency : 'BRL',
    weightUnit: isWeightUnit(s.weightUnit) ? s.weightUnit : 'g',
  }
}

export function applyDisplay(prefs: { currency?: unknown; weightUnit?: unknown }) {
  display.currency = isCurrency(prefs.currency) ? prefs.currency : 'BRL'
  display.weightUnit = isWeightUnit(prefs.weightUnit) ? prefs.weightUnit : 'g'
}

export const currencySymbol = (code: CurrencyCode = display.currency) => CURRENCIES[code].symbol

const currencyFormats = new Map<CurrencyCode, Intl.NumberFormat>()
/** Valor na moeda escolhida (ex.: R$ 7.000,00). */
export function money(v: number, code: CurrencyCode = display.currency): string {
  let f = currencyFormats.get(code)
  if (!f) {
    f = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: code })
    currencyFormats.set(code, f)
  }
  return f.format(Number.isFinite(v) ? v : 0)
}

export function formatNumber(v: number, minFraction = 0, maxFraction = 2): string {
  if (!Number.isFinite(v)) return ''
  return v.toLocaleString('pt-BR', {
    minimumFractionDigits: minFraction,
    maximumFractionDigits: Math.max(minFraction, maxFraction),
  })
}

/** Converte texto mascarado ("7.000,5") em número; vazio retorna NaN. */
export function parseMasked(text: string): number {
  const cleaned = text.replace(/[^\d,-]/g, '').replace(',', '.')
  if (cleaned === '' || cleaned === '.') return NaN
  return Number(cleaned.startsWith('.') ? `0${cleaned}` : cleaned)
}

const MAX_INTEGER_DIGITS = 12

const group = (digits: string) => digits.replace(/\B(?=(\d{3})+(?!\d))/g, '.')

/**
 * Máscara aplicada enquanto se digita. Vírgula é sempre o decimal; um ponto digitado
 * (ou colado) seguido de até `maxFraction` dígitos vira vírgula ("31.17" → "31,17").
 * Pontos de milhar já exibidos são ignorados.
 */
export function liveMask(input: string, previous = '', maxFraction = 2): string {
  let decimalIndex = -1
  if (maxFraction > 0) {
    const comma = input.indexOf(',')
    if (comma >= 0) {
      decimalIndex = comma
    } else {
      let prefix = 0
      while (prefix < input.length && prefix < previous.length && input[prefix] === previous[prefix]) prefix++
      let suffix = 0
      while (
        suffix < input.length - prefix &&
        suffix < previous.length - prefix &&
        input[input.length - 1 - suffix] === previous[previous.length - 1 - suffix]
      )
        suffix++
      const inserted = input.slice(prefix, input.length - suffix)
      const dot = inserted.lastIndexOf('.')
      if (dot >= 0) {
        const at = prefix + dot
        const digitsAfter = input.slice(at + 1).split('.')[0].replace(/\D/g, '').length
        if (digitsAfter <= maxFraction) decimalIndex = at
      }
    }
  }

  const intSource = decimalIndex >= 0 ? input.slice(0, decimalIndex) : input
  let digits = intSource.replace(/\D/g, '').replace(/^0+(?=\d)/, '').slice(0, MAX_INTEGER_DIGITS)
  if (decimalIndex < 0) return group(digits)
  if (digits === '') digits = '0'
  const fraction = input.slice(decimalIndex + 1).replace(/\D/g, '').slice(0, maxFraction)
  return `${group(digits)},${fraction}`
}

// Peso

export const toGrams = (v: number, unit: WeightUnitId = display.weightUnit) => v * WEIGHT_UNITS[unit].grams
export const fromGrams = (g: number, unit: WeightUnitId = display.weightUnit) => g / WEIGHT_UNITS[unit].grams

/** Peso em gramas na unidade escolhida (ex.: 31,17 g ou 0,031 kg). */
export const weight = (grams: number, unit: WeightUnitId = display.weightUnit) =>
  `${formatNumber(fromGrams(grams, unit), 0, WEIGHT_UNITS[unit].digits)} ${unit}`

/** Preço do filamento em R$/kg ou R$/lb. */
export function pricePerBulk(perGram: number, unit: WeightUnitId = display.weightUnit) {
  const bulk = WEIGHT_UNITS[unit].bulk
  return `${money(perGram * WEIGHT_UNITS[bulk].grams)}/${bulk}`
}

// Máscaras de texto

/** Telefone: (11) 3000-0000 ou (11) 90000-0000. Texto com letras ou "@" fica como está. */
export function phoneMask(input: string): string {
  if (/[a-zA-ZÀ-ÿ@]/.test(input)) return input
  const d = input.replace(/\D/g, '').slice(0, 11)
  if (!d) return ''
  if (d.length <= 2) return `(${d}`
  if (d.length <= 6) return `(${d.slice(0, 2)}) ${d.slice(2)}`
  if (d.length <= 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`
  return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`
}

/** CPF (000.000.000-00) ou CNPJ (00.000.000/0000-00), inclusive o CNPJ alfanumérico. */
export function cpfCnpjMask(input: string): string {
  const raw = input.toUpperCase().replace(/[^0-9A-Z]/g, '').slice(0, 14)
  if (!raw) return ''
  const isCPF = raw.length <= 11 && /^\d+$/.test(raw)
  const separators: Record<number, string> = isCPF ? { 3: '.', 6: '.', 9: '-' } : { 2: '.', 5: '.', 8: '/', 12: '-' }
  let out = ''
  for (let i = 0; i < raw.length; i++) out += (separators[i] ?? '') + raw[i]
  return out
}
