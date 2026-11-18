import type { CostResult, PrintJob, ShopSettings } from './calculator'
import type { StockDeduction } from './filament'

export const uid = () => crypto.randomUUID()

/** Cálculo de peça salvo no histórico, com os parâmetros usados na época. */
export interface QuoteRecord {
  id: string
  savedAt: string
  job: PrintJob
  settings: ShopSettings
  result: CostResult
}

export const MAX_QUANTITY = 9999
/** R$ 1 bilhão por unidade: mantém subtotais dentro da precisão exata do JavaScript. */
const MAX_CENTS = 100_000_000_000

/** Converte reais para centavos inteiros, sem valores negativos ou inválidos. */
export function toCents(value: number): number {
  if (!Number.isFinite(value) || value <= 0) return 0
  return Math.min(Math.round(value * 100), MAX_CENTS)
}
export const fromCents = (cents: number) => cents / 100

export const clampQuantity = (q: number) =>
  Number.isFinite(q) ? Math.min(Math.max(Math.round(q), 1), MAX_QUANTITY) : 1

/** Item do orçamento, com valores copiados no momento da inclusão. */
export interface ProposalItem {
  id: string
  name: string
  details: string
  quantity: number
  unitPriceCents: number
  sourceQuoteId: string | null
  /** Foto do produto; sem foto, usa a imagem padrão. */
  imageId: string | null
  /** Filamento da biblioteca e consumo por unidade (g), copiados na inclusão. */
  filamentId: string | null
  filamentName: string
  gramsPerUnit: number | null
}

export interface Proposal {
  id: string
  /** Número sequencial, atribuído no primeiro salvamento. */
  number: number | null
  title: string
  createdAt: string
  updatedAt: string
  customerName: string
  customerContact: string
  customerDocument: string
  customerAddress: string
  items: ProposalItem[]
  discountCents: number
  shippingCents: number
  validityDays: number
  paymentTerms: string
  deliveryTime: string
  notes: string
  /** Baixas feitas no estoque de filamento por este orçamento (vazio = ainda não baixado). */
  stockDeductions: StockDeduction[]
  /** Quando a venda foi confirmada; null = ainda não vendido. */
  saleConfirmedAt: string | null
}

/** Dados da empresa e padrões usados para personalizar os orçamentos. */
export interface CompanyProfile {
  logoImageId: string | null
  companyName: string
  document: string
  responsibleName: string
  phone: string
  whatsapp: string
  email: string
  website: string
  instagram: string
  address: string
  accentColor: string
  showProductPhotos: boolean
  nextProposalNumber: number
  defaultValidityDays: number
  defaultPaymentTerms: string
  defaultDeliveryTime: string
  defaultNotes: string
  footerText: string
}

export const defaultCompany: CompanyProfile = {
  logoImageId: null,
  companyName: '',
  document: '',
  responsibleName: '',
  phone: '',
  whatsapp: '',
  email: '',
  website: '',
  instagram: '',
  address: '',
  accentColor: '#1e6fd9',
  showProductPhotos: true,
  nextProposalNumber: 1,
  defaultValidityDays: 15,
  defaultPaymentTerms: 'Pix, cartão de crédito ou boleto. 50% de entrada e 50% na entrega.',
  defaultDeliveryTime: 'Até 7 dias úteis após a aprovação.',
  defaultNotes: '',
  footerText: 'Obrigado pela preferência!',
}

export function newProposal(company: CompanyProfile, title = 'Novo orçamento'): Proposal {
  const now = new Date().toISOString()
  return {
    id: uid(),
    number: null,
    title,
    createdAt: now,
    updatedAt: now,
    customerName: '',
    customerContact: '',
    customerDocument: '',
    customerAddress: '',
    items: [],
    discountCents: 0,
    shippingCents: 0,
    validityDays: company.defaultValidityDays,
    paymentTerms: company.defaultPaymentTerms,
    deliveryTime: company.defaultDeliveryTime,
    notes: company.defaultNotes,
    stockDeductions: [],
    saleConfirmedAt: null,
  }
}

export function newItem(fields: Partial<ProposalItem> & { name: string; unitPrice: number }): ProposalItem {
  return {
    id: uid(),
    name: fields.name,
    details: fields.details ?? '',
    quantity: clampQuantity(fields.quantity ?? 1),
    unitPriceCents: toCents(fields.unitPrice),
    sourceQuoteId: fields.sourceQuoteId ?? null,
    imageId: fields.imageId ?? null,
    filamentId: fields.filamentId ?? null,
    filamentName: fields.filamentName ?? '',
    gramsPerUnit: fields.gramsPerUnit ?? null,
  }
}

export const itemSubtotalCents = (item: ProposalItem) => item.unitPriceCents * clampQuantity(item.quantity)
export const itemsTotalCents = (p: Proposal) => p.items.reduce((sum, i) => sum + itemSubtotalCents(i), 0)
export const totalCents = (p: Proposal) => Math.max(0, itemsTotalCents(p) + p.shippingCents - p.discountCents)

export const formattedNumber = (p: Proposal) => (p.number === null ? null : String(p.number).padStart(4, '0'))

export function validUntil(p: Proposal): Date | null {
  if (p.validityDays <= 0) return null
  const date = new Date(p.updatedAt)
  date.setDate(date.getDate() + p.validityDays)
  return date
}

/** Situação de um orçamento salvo: aguardando aprovação, vencido ou com venda confirmada. */
export type ProposalStatus = 'waiting' | 'expired' | 'sold'
export const PROPOSAL_STATUSES: ProposalStatus[] = ['waiting', 'expired', 'sold']

const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate())

/** Dias de calendário até o vencimento: 0 = vence hoje, negativo = já venceu. Null = sem validade. */
export function daysUntilExpiry(p: Proposal, now = new Date()): number | null {
  const until = validUntil(p)
  if (!until) return null
  return Math.round((startOfDay(until).getTime() - startOfDay(now).getTime()) / 86_400_000)
}

/** Venda confirmada vence qualquer prazo; o orçamento só vence depois do último dia de validade. */
export function proposalStatus(p: Proposal, now = new Date()): ProposalStatus {
  if (p.saleConfirmedAt) return 'sold'
  const days = daysUntilExpiry(p, now)
  return days !== null && days < 0 ? 'expired' : 'waiting'
}

/** Orçamentos de uma aba, na ordem mais útil para cada uma. */
export function proposalsIn(list: Proposal[], status: ProposalStatus, now = new Date()): Proposal[] {
  const time = (d: Date | null, fallback: number) => (d ? d.getTime() : fallback)
  const filtered = list.filter((p) => proposalStatus(p, now) === status)
  if (status === 'waiting') return filtered.sort((a, b) => time(validUntil(a), Infinity) - time(validUntil(b), Infinity))
  if (status === 'expired') return filtered.sort((a, b) => time(validUntil(b), 0) - time(validUntil(a), 0))
  return filtered.sort((a, b) => (b.saleConfirmedAt ?? '').localeCompare(a.saleConfirmedAt ?? ''))
}

export const displayName = (name: string, fallback: string) => name.trim() || fallback

/** Mescla dados salvos com os padrões atuais, para versões futuras não quebrarem o que já existe. */
export function withDefaults<T extends object>(defaults: T, value: unknown): T {
  if (!value || typeof value !== 'object') return { ...defaults }
  const result = { ...defaults }
  for (const key of Object.keys(defaults) as (keyof T)[]) {
    const v = (value as T)[key]
    if (v !== undefined && (typeof v === typeof defaults[key] || defaults[key] === null)) result[key] = v
  }
  return result
}

export function normalizeProposal(raw: Proposal): Proposal {
  const base = withDefaults(newProposal(defaultCompany), raw)
  return {
    ...base,
    id: raw.id,
    createdAt: raw.createdAt ?? base.createdAt,
    updatedAt: raw.updatedAt ?? base.updatedAt,
    validityDays: typeof raw.validityDays === 'number' ? raw.validityDays : 0,
    paymentTerms: raw.paymentTerms ?? '',
    deliveryTime: raw.deliveryTime ?? '',
    notes: raw.notes ?? '',
    stockDeductions: Array.isArray(raw.stockDeductions) ? raw.stockDeductions : [],
    items: (raw.items ?? []).map((i) => ({
      ...i,
      imageId: i.imageId ?? null,
      sourceQuoteId: i.sourceQuoteId ?? null,
      filamentId: i.filamentId ?? null,
      filamentName: i.filamentName ?? '',
      gramsPerUnit: i.gramsPerUnit ?? null,
    })),
  }
}
