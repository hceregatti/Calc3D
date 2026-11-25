import { applyDisplay, withValidDisplay } from './core/format'
import { create } from 'zustand'
import {
  calculate,
  canPrice,
  defaultJob,
  defaultSettings,
  type PrintJob,
  type ShopSettings,
} from './core/calculator'
import {
  defaultCompany,
  newItem,
  newProposal,
  normalizeProposal,
  proposalStatus,
  uid,
  withDefaults,
  type CompanyProfile,
  type Proposal,
  type ProposalItem,
  type ProposalStatus,
  type QuoteRecord,
} from './core/models'
import { deduct, filamentDisplayName, filamentPricePerGram, gramsPerUnit, newFilament, normalizeFilament, requirements, revert, type Filament } from './core/filament'
import { pruneImages } from './images'
import { extraScreens } from './extensions'

export type BuiltinScreen = 'home' | 'printJob' | 'parts' | 'filaments' | 'proposals' | 'company' | 'settings'
/** Telas próprias ou registradas por extensões (veja extensions.ts). */
export type Screen = BuiltinScreen | (string & {})
export const SCREENS: BuiltinScreen[] = ['home', 'printJob', 'parts', 'filaments', 'proposals', 'company', 'settings']

const KEYS = {
  settings: 'calc3d.web.settings.v1',
  job: 'calc3d.web.job.v1',
  company: 'calc3d.web.company.v1',
  quotes: 'calc3d.web.quotes.v1',
  proposals: 'calc3d.web.proposals.v1',
  filaments: 'calc3d.web.filaments.v1',
}

export type ThemeMode = 'system' | 'light' | 'dark'
const THEME_KEY = 'calc3d.web.theme'

/** Aplica o modo claro/escuro; 'system' remove o atributo e deixa o navegador decidir. */
export function applyTheme(mode: ThemeMode) {
  if (mode === 'system') document.documentElement.removeAttribute('data-theme')
  else document.documentElement.setAttribute('data-theme', mode)
}

export function loadTheme(): ThemeMode {
  const value = localStorage.getItem(THEME_KEY)
  return value === 'light' || value === 'dark' ? value : 'system'
}

export function saveTheme(mode: ThemeMode) {
  try {
    if (mode === 'system') localStorage.removeItem(THEME_KEY)
    else localStorage.setItem(THEME_KEY, mode)
  } catch { /* sem armazenamento: vale só nesta sessão */ }
  applyTheme(mode)
}

function load<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}

function save(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    useApp.getState().showToast('Não foi possível salvar: o armazenamento do navegador está cheio.', 'error')
  }
}

export interface ConfirmRequest {
  title: string
  message: string
  confirmLabel: string
  destructive?: boolean
  onConfirm: () => void
}

interface AppState {
  screen: Screen
  settings: ShopSettings
  savedSettings: ShopSettings
  company: CompanyProfile
  savedCompany: CompanyProfile
  job: PrintJob
  quotes: QuoteRecord[]
  filaments: Filament[]
  selectedFilamentId: string | null
  proposals: Proposal[]
  proposalDraft: Proposal | null
  /** Aba da lista de orçamentos. */
  proposalFilter: ProposalStatus
  selectedQuoteIds: string[]
  toast: { message: string; tone: 'success' | 'error' } | null
  confirm: ConfirmRequest | null

  go: (screen: Screen) => void
  showToast: (message: string, tone?: 'success' | 'error') => void
  askConfirm: (request: ConfirmRequest) => void
  closeConfirm: () => void

  setJob: (patch: Partial<PrintJob>) => void
  newJob: () => void

  setSettings: (patch: Partial<ShopSettings>) => void
  /** Define o filamento padrão a partir da biblioteca (null = valores manuais, que ficam como estão). */
  setDefaultFilament: (id: string | null) => void
  saveSettings: () => void
  resetSettings: () => void

  setCompany: (patch: Partial<CompanyProfile>) => void
  saveCompany: () => void
  resetCompanyConditions: () => void

  saveQuote: (job: PrintJob) => QuoteRecord
  renameQuote: (id: string, name: string) => void
  deleteQuote: (id: string) => void
  useQuoteAsBase: (quote: QuoteRecord) => void
  setSelectedQuoteIds: (ids: string[]) => void

  addFilament: () => void
  updateFilament: (id: string, patch: Partial<Filament>) => void
  duplicateFilament: (id: string) => void
  deleteFilament: (id: string) => void
  selectFilament: (id: string | null) => void
  /** Aplica (ou remove, com null) um filamento da biblioteca à peça informada. */
  filamentJobPatch: (id: string | null) => Partial<PrintJob>

  proposalHasUnsavedChanges: () => boolean
  guardDiscard: (action: () => void) => void
  startNewProposal: () => void
  openProposal: (id: string) => void
  updateDraft: (update: (p: Proposal) => void) => void
  updateItem: (id: string, patch: Partial<ProposalItem>) => void
  saveDraft: () => void
  setProposalFilter: (status: ProposalStatus) => void
  /** Marca o orçamento em edição como venda confirmada e salva. */
  confirmSale: () => void
  /** Desfaz a venda: volta para a fila (ou para os vencidos, se o prazo já passou). */
  reopenProposal: () => void
  /** Renova a validade a partir de hoje e devolve o orçamento vencido para a fila. */
  renewProposal: () => void
  /** Desconta o consumo do orçamento em edição dos rolos e salva o orçamento. */
  deductStock: () => void
  /** Devolve aos rolos o que o orçamento em edição tinha baixado. */
  revertStock: () => void
  deleteProposal: (id: string) => void
  addQuotesToDraft: (quotes: QuoteRecord[]) => void
  addQuotesToProposal: (quotes: QuoteRecord[], proposalId: string | null) => void

  replaceAll: (data: { settings: ShopSettings; company: CompanyProfile; quotes: QuoteRecord[]; proposals: Proposal[]; filaments?: Filament[] }) => void
  cleanupImages: () => void
}

const screenFromHash = (): Screen => {
  const hash = location.hash.replace('#/', '') as Screen
  return SCREENS.includes(hash as BuiltinScreen) || extraScreens.some((e) => e.id === hash) ? hash : 'home'
}

const sortProposals = (list: Proposal[]) => [...list].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))

function itemFromQuote(quote: QuoteRecord, fromHistory: boolean): ProposalItem | null {
  if (!canPrice(quote.result) || quote.result.suggestedPrice === null) return null
  return newItem({
    name: quote.job.name.trim() || 'Peça sem nome',
    unitPrice: quote.result.suggestedPrice,
    sourceQuoteId: fromHistory ? quote.id : null,
    imageId: quote.job.imageId ?? null,
    filamentId: quote.job.filamentId,
    filamentName: quote.job.filamentName,
    gramsPerUnit: gramsPerUnit(quote.job),
  })
}

const initialSettings = withValidDisplay(withDefaults(defaultSettings, load(KEYS.settings, null)))
applyDisplay(initialSettings)
const initialCompany = withDefaults(defaultCompany, load(KEYS.company, null))

/**
 * Mantém o filamento padrão alinhado à biblioteca quando o rolo é editado ou excluído.
 * A alteração também vai para os parâmetros já salvos, sem salvar outras edições pendentes.
 */
function syncDefaultFilament() {
  const { settings, savedSettings, filaments } = useApp.getState()
  const id = settings.defaultFilamentId
  if (!id) return
  const source = filaments.find((f) => f.id === id)
  const patch: Partial<ShopSettings> = source
    ? { spoolPrice: source.price, spoolWeight: source.netWeight }
    : { defaultFilamentId: null }
  const saved = { ...savedSettings, ...(savedSettings.defaultFilamentId === id ? patch : {}) }
  save(KEYS.settings, saved)
  useApp.setState({ settings: { ...settings, ...patch }, savedSettings: saved })
}

export const useApp = create<AppState>((set, get) => ({
  screen: screenFromHash(),
  settings: initialSettings,
  savedSettings: initialSettings,
  company: initialCompany,
  savedCompany: initialCompany,
  job: withDefaults(defaultJob, load(KEYS.job, null)),
  quotes: load<QuoteRecord[]>(KEYS.quotes, []),
  filaments: load<Filament[]>(KEYS.filaments, []).map(normalizeFilament),
  selectedFilamentId: null,
  proposals: sortProposals(load<Proposal[]>(KEYS.proposals, []).map(normalizeProposal)),
  proposalDraft: null,
  proposalFilter: 'waiting',
  selectedQuoteIds: [],
  toast: null,
  confirm: null,

  go: (screen) => {
    set({ screen })
    if (location.hash !== `#/${screen}`) history.replaceState(null, '', `#/${screen}`)
  },

  showToast: (message, tone = 'success') => {
    set({ toast: { message, tone } })
    const current = get().toast
    setTimeout(() => {
      if (get().toast === current) set({ toast: null })
    }, 2800)
  },

  askConfirm: (request) => set({ confirm: request }),
  closeConfirm: () => set({ confirm: null }),

  setJob: (patch) => {
    const job = { ...get().job, ...patch }
    set({ job })
    save(KEYS.job, job)
  },

  newJob: () => {
    get().setJob({ ...defaultJob })
    get().go('printJob')
  },

  setSettings: (patch) => {
    const settings = { ...get().settings, ...patch }
    applyDisplay(settings)
    set({ settings })
  },
  setDefaultFilament: (id) => {
    const f = id ? get().filaments.find((x) => x.id === id) : null
    get().setSettings(f ? { defaultFilamentId: f.id, spoolPrice: f.price, spoolWeight: f.netWeight } : { defaultFilamentId: null })
  },
  saveSettings: () => {
    const { settings } = get()
    save(KEYS.settings, settings)
    set({ savedSettings: settings })
    get().showToast('Parâmetros salvos ✔')
  },
  // Moeda e unidade são preferências: não voltam ao padrão.
  resetSettings: () => {
    const { currency, weightUnit } = get().settings
    set({ settings: { ...defaultSettings, currency, weightUnit } })
  },

  setCompany: (patch) => set({ company: { ...get().company, ...patch } }),
  saveCompany: () => {
    const { company } = get()
    save(KEYS.company, company)
    set({ savedCompany: company })
    get().showToast('Dados salvos ✔')
    get().cleanupImages()
  },
  resetCompanyConditions: () =>
    get().setCompany({
      defaultValidityDays: defaultCompany.defaultValidityDays,
      defaultPaymentTerms: defaultCompany.defaultPaymentTerms,
      defaultDeliveryTime: defaultCompany.defaultDeliveryTime,
      defaultNotes: defaultCompany.defaultNotes,
      footerText: defaultCompany.footerText,
    }),

  addFilament: () => {
    const filament = newFilament()
    const filaments = [filament, ...get().filaments]
    set({ filaments, selectedFilamentId: filament.id })
    save(KEYS.filaments, filaments)
  },

  updateFilament: (id, patch) => {
    const filaments = get().filaments.map((f) => (f.id === id ? { ...f, ...patch } : f))
    set({ filaments })
    save(KEYS.filaments, filaments)
    // Mantém o cálculo em andamento e o filamento padrão alinhados ao rolo editado.
    if (get().job.filamentId === id) get().setJob(get().filamentJobPatch(id))
    syncDefaultFilament()
  },

  duplicateFilament: (id) => {
    const source = get().filaments.find((f) => f.id === id)
    if (!source) return
    const copy = { ...source, id: uid(), createdAt: new Date().toISOString(), remainingWeight: source.netWeight }
    const filaments = [copy, ...get().filaments]
    set({ filaments, selectedFilamentId: copy.id })
    save(KEYS.filaments, filaments)
  },

  deleteFilament: (id) => {
    const filaments = get().filaments.filter((f) => f.id !== id)
    set({ filaments, selectedFilamentId: get().selectedFilamentId === id ? null : get().selectedFilamentId })
    save(KEYS.filaments, filaments)
    syncDefaultFilament()
  },

  selectFilament: (id) => set({ selectedFilamentId: id }),

  filamentJobPatch: (id) => {
    const f = get().filaments.find((x) => x.id === id)
    return f
      ? { filamentId: f.id, filamentName: filamentDisplayName(f), filamentPricePerGram: filamentPricePerGram(f) }
      : { filamentId: null, filamentName: '', filamentPricePerGram: null }
  },

  saveQuote: (job) => {
    const { settings } = get()
    const quote: QuoteRecord = {
      id: uid(),
      savedAt: new Date().toISOString(),
      job: { ...job },
      settings: { ...settings },
      result: calculate(settings, job),
    }
    const quotes = [quote, ...get().quotes]
    set({ quotes })
    save(KEYS.quotes, quotes)
    return quote
  },

  renameQuote: (id, name) => {
    const trimmed = name.trim()
    if (!trimmed) return
    const quotes = get().quotes.map((q) => (q.id === id ? { ...q, job: { ...q.job, name: trimmed } } : q))
    set({ quotes })
    save(KEYS.quotes, quotes)
  },

  deleteQuote: (id) => {
    const quotes = get().quotes.filter((q) => q.id !== id)
    set({ quotes, selectedQuoteIds: get().selectedQuoteIds.filter((s) => s !== id) })
    save(KEYS.quotes, quotes)
    get().cleanupImages()
  },

  useQuoteAsBase: (quote) => {
    get().setJob({ ...quote.job })
    get().go('printJob')
  },

  setSelectedQuoteIds: (ids) => set({ selectedQuoteIds: ids }),

  proposalHasUnsavedChanges: () => {
    const { proposalDraft, proposals } = get()
    if (!proposalDraft) return false
    const saved = proposals.find((p) => p.id === proposalDraft.id)
    return !saved || JSON.stringify(saved) !== JSON.stringify(proposalDraft)
  },

  guardDiscard: (action) => {
    if (!get().proposalHasUnsavedChanges()) return action()
    get().askConfirm({
      title: 'Descartar alterações?',
      message: 'As alterações não salvas neste orçamento serão perdidas.',
      confirmLabel: 'Descartar e continuar',
      destructive: true,
      onConfirm: action,
    })
  },

  startNewProposal: () =>
    get().guardDiscard(() => {
      set({ proposalDraft: newProposal(get().savedCompany) })
      get().go('proposals')
    }),

  openProposal: (id) => {
    if (get().proposalDraft?.id === id) return get().go('proposals')
    get().guardDiscard(() => {
      const proposal = get().proposals.find((p) => p.id === id)
      if (!proposal) return
      set({ proposalDraft: structuredClone(proposal), proposalFilter: proposalStatus(proposal) })
      get().go('proposals')
    })
  },

  updateDraft: (update) => {
    const draft = get().proposalDraft
    if (!draft) return
    const copy = structuredClone(draft)
    update(copy)
    set({ proposalDraft: copy })
  },

  updateItem: (id, patch) =>
    get().updateDraft((p) => {
      const item = p.items.find((i) => i.id === id)
      if (item) Object.assign(item, patch)
    }),

  saveDraft: () => {
    const draft = get().proposalDraft
    if (!draft) return
    const proposal = structuredClone(draft)
    proposal.updatedAt = new Date().toISOString()
    if (proposal.number === null) {
      // Reserva o próximo número sem descartar edições pendentes do perfil.
      const { savedCompany, company } = get()
      const number = Math.max(savedCompany.nextProposalNumber, 1)
      const nextSaved = { ...savedCompany, nextProposalNumber: number + 1 }
      save(KEYS.company, nextSaved)
      set({
        savedCompany: nextSaved,
        company:
          company.nextProposalNumber === savedCompany.nextProposalNumber
            ? { ...company, nextProposalNumber: number + 1 }
            : company,
      })
      proposal.number = number
    }
    const proposals = sortProposals([proposal, ...get().proposals.filter((p) => p.id !== proposal.id)])
    set({ proposals, proposalDraft: structuredClone(proposal), proposalFilter: proposalStatus(proposal) })
    save(KEYS.proposals, proposals)
    get().showToast('Orçamento salvo ✔')
    get().cleanupImages()
  },

  setProposalFilter: (proposalFilter) => set({ proposalFilter }),

  confirmSale: () => {
    if (!get().proposalDraft) return
    get().updateDraft((p) => void (p.saleConfirmedAt = new Date().toISOString()))
    get().saveDraft()
  },

  reopenProposal: () => {
    if (!get().proposalDraft) return
    get().updateDraft((p) => void (p.saleConfirmedAt = null))
    get().saveDraft()
  },

  // Salvar já reinicia a contagem da validade (updatedAt).
  renewProposal: () => get().saveDraft(),

  deductStock: () => {
    const draft = get().proposalDraft
    if (!draft || draft.stockDeductions.length) return
    const reqs = requirements(draft.items.map((i) => ({ filamentId: i.filamentId, filamentName: i.filamentName, gramsPerUnit: i.gramsPerUnit, quantity: i.quantity })))
    const { filaments, deductions } = deduct(reqs, get().filaments)
    if (!deductions.length) return
    set({ filaments })
    save(KEYS.filaments, filaments)
    get().updateDraft((p) => void (p.stockDeductions = deductions))
    get().saveDraft()
  },

  revertStock: () => {
    const draft = get().proposalDraft
    if (!draft || !draft.stockDeductions.length) return
    const filaments = revert(draft.stockDeductions, get().filaments)
    set({ filaments })
    save(KEYS.filaments, filaments)
    get().updateDraft((p) => void (p.stockDeductions = []))
    get().saveDraft()
  },

  deleteProposal: (id) => {
    const proposals = get().proposals.filter((p) => p.id !== id)
    set({ proposals, proposalDraft: get().proposalDraft?.id === id ? null : get().proposalDraft })
    save(KEYS.proposals, proposals)
    get().cleanupImages()
  },

  addQuotesToDraft: (quotes) => {
    const ids = new Set(get().quotes.map((q) => q.id))
    const items = quotes.map((q) => itemFromQuote(q, ids.has(q.id))).filter((i): i is ProposalItem => i !== null)
    if (items.length) get().updateDraft((p) => p.items.push(...items))
  },

  addQuotesToProposal: (quotes, proposalId) => {
    const priced = quotes.filter((q) => canPrice(q.result))
    if (!priced.length) return
    get().guardDiscard(() => {
      const base = proposalId ? get().proposals.find((p) => p.id === proposalId) : newProposal(get().savedCompany)
      if (!base) return
      set({ proposalDraft: structuredClone(base) })
      get().addQuotesToDraft(priced)
      get().saveDraft()
      get().go('proposals')
    })
  },

  replaceAll: ({ settings, company, quotes, proposals, filaments: rawFilaments }) => {
    const s = withValidDisplay(withDefaults(defaultSettings, settings))
    applyDisplay(s)
    const c = withDefaults(defaultCompany, company)
    const p = sortProposals(proposals.map(normalizeProposal))
    save(KEYS.settings, s)
    save(KEYS.company, c)
    save(KEYS.quotes, quotes)
    const fl = (rawFilaments ?? []).map(normalizeFilament)
    save(KEYS.proposals, p)
    save(KEYS.filaments, fl)
    set({
      filaments: fl,
      selectedFilamentId: null,
      settings: s,
      savedSettings: s,
      company: c,
      savedCompany: c,
      quotes,
      proposals: p,
      proposalDraft: null,
      selectedQuoteIds: [],
    })
    get().cleanupImages()
  },

  /** Mantém só as imagens usadas por orçamentos salvos, o rascunho e o perfil. */
  cleanupImages: () => {
    const { proposals, proposalDraft, company, savedCompany, quotes, job } = get()
    const keep = new Set<string>()
    for (const q of quotes) if (q.job.imageId) keep.add(q.job.imageId)
    if (job.imageId) keep.add(job.imageId)
    for (const p of [...proposals, ...(proposalDraft ? [proposalDraft] : [])]) {
      for (const item of p.items) if (item.imageId) keep.add(item.imageId)
    }
    if (company.logoImageId) keep.add(company.logoImageId)
    if (savedCompany.logoImageId) keep.add(savedCompany.logoImageId)
    pruneImages(keep).catch(() => {})
  },
}))

window.addEventListener('hashchange', () => useApp.setState({ screen: screenFromHash() }))
