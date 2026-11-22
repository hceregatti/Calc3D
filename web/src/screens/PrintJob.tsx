import { ImageSlot } from '../components/ImageSlot'
import {
  AlertTriangle,
  Bookmark,
  Box,
  Copy,
  Download,
  FilePlus2,
  Paintbrush,
  Plus,
  SlidersHorizontal,
  Tag,
  BadgeDollarSign,
} from 'lucide-react'
import { useMemo, useRef, useState } from 'react'
import {
  CATEGORIES,
  PRICING_ERROR,
  money,
  calculate,
  canPrice,
  derived,
  percent,
  plateCost,
  profitPerMachineHour,
  profitPerPart,
  quoteSummary,
  shareOf,
  unitCost,
  type CostResult,
  type PrintJob,
  type ShopSettings,
} from '../core/calculator'
import { pricePerBulk } from '../core/format'
import { importModelFile } from '../core/importer'
import { filamentDisplayName } from '../core/filament'
import { displayName, uid } from '../core/models'
import { Donut } from '../components/Donut'
import { NumberField, PageHeader, Row, Section, Stepper, TextField } from '../components/ui'
import { useApp } from '../store'

export function PrintJobScreen() {
  const job = useApp((s) => s.job)
  const setJob = useApp((s) => s.setJob)
  const settings = useApp((s) => s.settings)
  const go = useApp((s) => s.go)
  const newJob = useApp((s) => s.newJob)
  const result = useMemo(() => calculate(settings, job), [settings, job])

  return (
    <div className="page">
      <PageHeader title="Calcular peça">
        <button className="btn" onClick={newJob}>
          <Plus size={16} /> Nova peça
        </button>
      </PageHeader>
      <div className="split">
        <div className="split-main">
          <PartForm job={job} setJob={setJob} settings={settings} onEditSettings={() => go('settings')} />
        </div>
        <aside className="split-side">
          <PriceCard result={result} />
          <BreakdownCard result={result} />
          <ResultActions job={job} result={result} />
        </aside>
      </div>
    </div>
  )
}

/** Formulário da peça, usado na tela principal e no cálculo dentro do orçamento. */
export function PartForm({
  job,
  setJob,
  settings,
  onEditSettings,
}: {
  job: PrintJob
  setJob: (patch: Partial<PrintJob>) => void
  settings: ShopSettings
  onEditSettings?: () => void
}) {
  const file = useRef<HTMLInputElement>(null)
  const [importing, setImporting] = useState(false)
  const [feedback, setFeedback] = useState<{ text: string; warn: boolean } | null>(null)
  const [missing, setMissing] = useState({ weight: false, time: false })

  const onImport = async (f: File | undefined) => {
    if (!f) return
    setImporting(true)
    setFeedback(null)
    try {
      const data = await importModelFile(f)
      const seconds = data.durationSeconds ?? 0
      const minutes = seconds / 60
      setJob({
        name: data.name,
        partWeight: data.weightGrams ?? 0,
        printHours: Math.floor(minutes / 60),
        printMinutes: Math.round((minutes % 60) * 100) / 100,
      })
      const m = { weight: data.weightGrams === null, time: !seconds }
      setMissing(m)
      const list = [m.weight && 'peso', m.time && 'tempo de impressão'].filter(Boolean)
      setFeedback(
        list.length
          ? { text: `Arquivo importado; preencha: ${list.join(' e ')}.`, warn: true }
          : { text: 'Dados importados. Revise os valores antes de calcular.', warn: false },
      )
    } catch (e) {
      setFeedback({ text: (e as Error).message, warn: true })
    } finally {
      setImporting(false)
    }
  }

  const d = derived(settings)

  return (
    <>
      <Section title="Identificação" icon={Tag} color="#0a84ff">
        <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
          <ImageSlot imageId={job.imageId ?? null} kind="product" label="Foto da peça" onChange={(imageId) => setJob({ imageId })} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <TextField label="Nome da peça ou pedido" value={job.name} placeholder="Ex.: Suporte de headset" onChange={(name) => setJob({ name })} />
          </div>
        </div>
        <div className="row">
          <button className="btn" disabled={importing} onClick={() => file.current?.click()}>
            <Download size={16} /> {importing ? 'Lendo arquivo…' : 'Importar STL ou 3MF'}
          </button>
          <input ref={file} type="file" accept=".stl,.3mf" hidden onChange={(e) => {
            onImport(e.target.files?.[0])
            e.target.value = ''
          }} />
        </div>
        {feedback && <p className={`feedback ${feedback.warn ? 'warn' : ''}`}>{feedback.text}</p>}
      </Section>

      <Section title="Fatiador" icon={Box} color="#ff9f0a">
        <FilamentPicker job={job} setJob={setJob} weightUnit={settings.weightUnit} />
        <NumberField
          label="Peso da mesa"
          kind="weight"
          value={job.partWeight}
          warn={missing.weight}
          hint={missing.weight ? 'Não encontrado no arquivo. Preencha o peso do fatiador.' : 'Valor do fatiador, somando todas as peças'}
          onChange={(partWeight) => {
            setMissing((m) => ({ ...m, weight: false }))
            setJob({ partWeight })
          }}
        />
        <NumberField label="Desperdício" unit="%" max={300} value={job.wastePercent}
          hint="Purga, skirt/brim e troca de cor (AMS/MMU pode passar de 20%)" onChange={(wastePercent) => setJob({ wastePercent })} />
        <NumberField
          label="Horas"
          unit="h"
          value={job.printHours}
          warn={missing.time}
          hint={missing.time ? 'Não encontrado no arquivo. Preencha o tempo do fatiador.' : undefined}
          onChange={(printHours) => {
            setMissing((m) => ({ ...m, time: false }))
            setJob({ printHours })
          }}
        />
        <NumberField label="Minutos" unit="min" max={59} value={job.printMinutes} onChange={(printMinutes) => setJob({ printMinutes })} />
        <Row label="Peças por mesa" hint="O custo da mesa é dividido entre as peças">
          <Stepper label="Peças por mesa" value={job.partsPerPlate} min={1} max={999} onChange={(partsPerPlate) => setJob({ partsPerPlate })} />
          <span className="unit">un</span>
        </Row>
      </Section>

      <Section title="Trabalho e acabamento" icon={Paintbrush} color="#ff375f">
        <NumberField label="Preparação" unit="min" value={job.setupMinutes} hint="Fatiar, preparar a mesa, retirar a peça" onChange={(setupMinutes) => setJob({ setupMinutes })} />
        <NumberField label="Pós-processamento" unit="min" value={job.postProcessingMinutes} hint="Remover suportes, lixar, pintar" onChange={(postProcessingMinutes) => setJob({ postProcessingMinutes })} />
        <NumberField label="Insumos desta mesa" kind="money" value={job.consumablesPerPlate} hint="Cola, lixa, tinta, primer, ímãs, parafusos" onChange={(consumablesPerPlate) => setJob({ consumablesPerPlate })} />
      </Section>

      <Section title="Preço" icon={BadgeDollarSign} color="#30d158">
        <NumberField label="Margem de lucro" unit="%" max={95} value={job.marginPercent}
          hint="Margem sobre o preço, não markup: 40% = custo ÷ 0,60" onChange={(marginPercent) => setJob({ marginPercent })} />
      </Section>

      <Section
        title="Parâmetros fixos em uso"
        icon={SlidersHorizontal}
        color="#8e8e93"
        action={onEditSettings && <button className="link" onClick={onEditSettings}>Editar…</button>}
      >
        <Row label="Filamento">{pricePerBulk(job.filamentPricePerGram ?? d.filamentPricePerGram, settings.weightUnit)}</Row>
        <Row label="Hora de máquina">{money(d.machineCostPerHour)}/h</Row>
        <Row label="Valor da sua hora">{money(settings.laborRate)}/h</Row>
        <Row label="Taxa de falha">{percent(settings.failureRatePercent / 100)}</Row>
        <Row label="Impostos + taxas">
          {percent((settings.taxPercent + settings.marketplaceFeePercent) / 100)} + {money(settings.fixedFeePerSale)}
        </Row>
      </Section>
    </>
  )
}

export function PriceCard({ result }: { result: CostResult }) {
  const profit = profitPerPart(result)
  const perHour = profitPerMachineHour(result)
  return (
    <div className="card">
      <span className="muted">Preço sugerido por peça</span>
      <div className="price">{result.suggestedPrice === null ? '—' : money(result.suggestedPrice)}</div>
      {result.suggestedPrice === null && (
        <p className="error-text">
          <AlertTriangle size={14} /> {PRICING_ERROR}
        </p>
      )}
      <div className="kpis">
        <Kpi title="Custo por peça" value={money(unitCost(result))} />
        <Kpi title="Lucro líquido/peça" value={profit === null ? '—' : money(profit)} />
        <Kpi title="Custo da mesa" value={money(plateCost(result))} />
        <Kpi title="Lucro por hora" value={perHour === null ? '—' : `${money(perHour)}/h`} />
      </div>
    </div>
  )
}

function Kpi({ title, value }: { title: string; value: string }) {
  return (
    <div className="kpi">
      <strong>{value}</strong>
      <small>{title}</small>
    </div>
  )
}

export function BreakdownCard({ result }: { result: CostResult }) {
  return (
    <div className="card">
      <h3>Composição do custo por peça</h3>
      <Donut result={result} />
      <ul className="breakdown">
        {result.items.map((item) => {
          const c = CATEGORIES.find((x) => x.id === item.category)!
          return (
            <li key={item.category}>
              <span className="dot" style={{ background: c.color }} />
              <span className="grow">{c.title}</span>
              <span className="num">{money(item.amount)}</span>
              <small className="num share">{percent(shareOf(result, item.category))}</small>
            </li>
          )
        })}
        <li className="total">
          <span className="grow">Custo total por peça</span>
          <span className="num">{money(unitCost(result))}</span>
        </li>
      </ul>
    </div>
  )
}

function ResultActions({ job, result }: { job: PrintJob; result: CostResult }) {
  const saveQuote = useApp((s) => s.saveQuote)
  const showToast = useApp((s) => s.showToast)
  const proposals = useApp((s) => s.proposals)
  const settings = useApp((s) => s.settings)
  const addQuotesToProposal = useApp((s) => s.addQuotesToProposal)
  const newJob = useApp((s) => s.newJob)
  const [menu, setMenu] = useState(false)

  const addTo = (proposalId: string | null) => {
    setMenu(false)
    // Cálculo avulso: não fica vinculado ao histórico.
    addQuotesToProposal([{ id: uid(), savedAt: new Date().toISOString(), job, settings, result }], proposalId)
  }

  return (
    <div className="actions-col">
      <div className="btn-row">
        <button className="btn primary" onClick={() => {
          saveQuote(job)
          showToast('Peça salva no histórico ✔')
        }}>
          <Bookmark size={16} /> Salvar peça
        </button>
        <button className="btn" onClick={async () => {
          try {
            await navigator.clipboard.writeText(quoteSummary(result, job))
            showToast('Orçamento copiado ✔')
          } catch {
            showToast('Não foi possível copiar.', 'error')
          }
        }}>
          <Copy size={16} /> Copiar
        </button>
      </div>
      <div className="menu-wrap">
        <button className="btn full" disabled={!canPrice(result)} onClick={() => setMenu(!menu)}
          title="Adiciona o cálculo atual a um orçamento sem salvá-lo no histórico de peças">
          <FilePlus2 size={16} /> Adicionar a orçamento
        </button>
        {menu && (
          <div className="menu" onMouseLeave={() => setMenu(false)}>
            <button onClick={() => addTo(null)}>Novo orçamento</button>
            {proposals.length > 0 && <div className="menu-label">Orçamentos existentes</div>}
            {proposals.map((p) => (
              <button key={p.id} onClick={() => addTo(p.id)}>{displayName(p.title, 'Orçamento sem título')}</button>
            ))}
          </div>
        )}
      </div>
      <button className="btn ghost" onClick={newJob}>Nova peça</button>
    </div>
  )
}

/** Escolha do filamento da biblioteca; sem escolha vale o rolo padrão dos parâmetros fixos. */
function FilamentPicker({ job, setJob, weightUnit }: { job: PrintJob; setJob: (patch: Partial<PrintJob>) => void; weightUnit: ShopSettings['weightUnit'] }) {
  const filaments = useApp((s) => s.filaments)
  const filamentJobPatch = useApp((s) => s.filamentJobPatch)
  const removed = job.filamentId !== null && !filaments.some((f) => f.id === job.filamentId)
  return (
    <Row
      label="Filamento"
      hint={job.filamentPricePerGram !== null ? `Preço: ${pricePerBulk(job.filamentPricePerGram, weightUnit)}` : 'Cadastre rolos na aba Filamentos'}
    >
      <select className="input" style={{ width: 260 }} aria-label="Filamento" value={job.filamentId ?? ''}
        onChange={(e) => setJob(filamentJobPatch(e.target.value || null))}>
        <option value="">Padrão dos parâmetros fixos</option>
        {removed && <option value={job.filamentId!}>{job.filamentName || 'Filamento removido'} (removido)</option>}
        {filaments.map((f) => (
          <option key={f.id} value={f.id}>{filamentDisplayName(f)}</option>
        ))}
      </select>
    </Row>
  )
}
