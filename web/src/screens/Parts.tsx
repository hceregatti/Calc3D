import { Box, FilePlus2, Layers, Plus, RotateCcw, Settings, Trash2, PieChart } from 'lucide-react'
import { useEffect, useState } from 'react'
import { CATEGORIES, PRICING_ERROR, money, canPrice, derived, number, plateCost, unitCost } from '../core/calculator'
import { pricePerBulk, weight } from '../core/format'
import { displayName, type QuoteRecord } from '../core/models'
import { Empty, PageHeader, Row, Section } from '../components/ui'
import { useApp } from '../store'

export function PartsScreen() {
  const { quotes, selectedQuoteIds, setSelectedQuoteIds, newJob, addQuotesToProposal } = useApp()
  const selected = quotes.filter((q) => selectedQuoteIds.includes(q.id))

  const toggle = (id: string) =>
    setSelectedQuoteIds(selectedQuoteIds.includes(id) ? selectedQuoteIds.filter((s) => s !== id) : [...selectedQuoteIds, id])

  return (
    <div className="page">
      <PageHeader title="Peças">
        <button className="btn" onClick={newJob}>
          <Plus size={16} /> Calcular peça
        </button>
        <button className="btn primary" disabled={!selected.some((q) => canPrice(q.result))} onClick={() => addQuotesToProposal(selected, null)}>
          <FilePlus2 size={16} /> Gerar orçamento
        </button>
      </PageHeader>
      <div className="master-detail">
        <div className="master">
          {quotes.length === 0 ? (
            <Empty icon={Layers} title="Nenhuma peça salva" text="Calcule uma peça e clique em “Salvar peça” para guardá-la aqui.">
              <button className="btn" onClick={newJob}>Calcular peça</button>
            </Empty>
          ) : (
            <>
              <div className="list">
                {quotes.map((q) => (
                  <div
                    key={q.id}
                    className={`list-row ${selectedQuoteIds.includes(q.id) ? 'selected' : ''}`}
                    onClick={(e) => {
                      if (e.metaKey || e.ctrlKey || e.shiftKey) toggle(q.id)
                      else setSelectedQuoteIds([q.id])
                    }}
                  >
                    <input
                      type="checkbox"
                      checked={selectedQuoteIds.includes(q.id)}
                      onClick={(e) => e.stopPropagation()}
                      onChange={() => toggle(q.id)}
                      aria-label="Selecionar peça"
                    />
                    <div className="grow text">
                      <strong className="ellipsis">{displayName(q.job.name, 'Peça sem nome')}</strong>
                      <small className="muted">
                        {new Date(q.savedAt).toLocaleString('pt-BR', { dateStyle: 'medium', timeStyle: 'short' })}
                      </small>
                    </div>
                    <span className="num muted">{q.result.suggestedPrice === null ? 'Sem preço' : money(q.result.suggestedPrice)}</span>
                  </div>
                ))}
              </div>
              <div className="list-footer">
                <small className="muted">Marque as caixas para selecionar várias</small>
                <button
                  className="link"
                  onClick={() => setSelectedQuoteIds(selectedQuoteIds.length === quotes.length ? [] : quotes.map((q) => q.id))}
                >
                  {selectedQuoteIds.length === quotes.length ? 'Limpar' : 'Selecionar todas'}
                </button>
              </div>
            </>
          )}
        </div>
        <div className="detail">
          {selected.length === 1 ? (
            <QuoteDetail quote={selected[0]} />
          ) : selected.length > 1 ? (
            <MultipleSummary quotes={selected} />
          ) : quotes.length ? (
            <Empty icon={Layers} title="Selecione peças" text="Selecione uma peça para ver os detalhes, ou várias para gerar um orçamento." />
          ) : null}
        </div>
      </div>
    </div>
  )
}

export function AddToProposalMenu({ quotes, label }: { quotes: QuoteRecord[]; label?: string }) {
  const { proposals, addQuotesToProposal } = useApp()
  const [open, setOpen] = useState(false)
  const count = quotes.filter((q) => canPrice(q.result)).length
  return (
    <div className="menu-wrap">
      <button className="btn" disabled={count === 0} onClick={() => setOpen(!open)}>
        <FilePlus2 size={16} /> {label ?? (count > 1 ? `Adicionar ${count} peças a orçamento` : 'Adicionar a orçamento')}
      </button>
      {open && (
        <div className="menu" onMouseLeave={() => setOpen(false)}>
          <button onClick={() => { setOpen(false); addQuotesToProposal(quotes, null) }}>Novo orçamento</button>
          {proposals.length > 0 && <div className="menu-label">Orçamentos existentes</div>}
          {proposals.map((p) => (
            <button key={p.id} onClick={() => { setOpen(false); addQuotesToProposal(quotes, p.id) }}>
              {displayName(p.title, 'Orçamento sem título')}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

function QuoteDetail({ quote }: { quote: QuoteRecord }) {
  const { renameQuote, useQuoteAsBase, deleteQuote, askConfirm } = useApp()
  const [name, setName] = useState(quote.job.name)
  useEffect(() => setName(quote.job.name), [quote.id, quote.job.name])
  const r = quote.result
  const d = derived(quote.settings)
  const canSave = name.trim() !== '' && name.trim() !== quote.job.name

  return (
    <div className="detail-inner">
      <div className="title-edit">
        <input className="input title" value={name} placeholder="Nome da peça" onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && canSave && renameQuote(quote.id, name)} />
        <button className="btn" disabled={!canSave} onClick={() => renameQuote(quote.id, name)}>Salvar nome</button>
      </div>
      <p className="muted">Salvo em {new Date(quote.savedAt).toLocaleString('pt-BR', { dateStyle: 'long', timeStyle: 'short' })}</p>

      <div className="card">
        <span className="muted">Preço sugerido por peça</span>
        <div className="price">{r.suggestedPrice === null ? 'Indisponível' : money(r.suggestedPrice)}</div>
        {r.suggestedPrice === null && <p className="error-text">{PRICING_ERROR}</p>}
      </div>

      <Section title="Dados da impressão" icon={Box} color="#ff9f0a">
        <Row label="Peso da mesa">{weight(quote.job.partWeight)}</Row>
        <Row label="Tempo de impressão">{number(r.printHours)} h</Row>
        <Row label="Peças por mesa">{r.partsPerPlate}</Row>
        <Row label="Custo por peça">{money(unitCost(r))}</Row>
        <Row label="Custo da mesa">{money(plateCost(r))}</Row>
      </Section>

      <Section title="Composição do custo por peça" icon={PieChart} color="#5e5ce6">
        {r.items.map((i) => (
          <Row key={i.category} label={CATEGORIES.find((c) => c.id === i.category)!.title}>{money(i.amount)}</Row>
        ))}
        <Row label={<strong>Total</strong>}><strong>{money(unitCost(r))}</strong></Row>
      </Section>

      <Section title="Parâmetros fixos salvos" icon={Settings} color="#8e8e93">
        <Row label="Filamento">{pricePerBulk(d.filamentPricePerGram)}</Row>
        <Row label="Hora de máquina">{money(d.machineCostPerHour)}/h</Row>
        <Row label="Valor da hora">{money(quote.settings.laborRate)}/h</Row>
      </Section>

      <div className="btn-row">
        <AddToProposalMenu quotes={[quote]} />
        <button className="btn" onClick={() => useQuoteAsBase(quote)}>
          <RotateCcw size={16} /> Usar como base
        </button>
        <span className="grow" />
        <button className="btn danger-text" onClick={() => askConfirm({
          title: 'Excluir peça?',
          message: `${quote.job.name ? `"${quote.job.name}"` : 'Esta peça'} será removida do histórico. Orçamentos já criados não mudam.`,
          confirmLabel: 'Excluir',
          destructive: true,
          onConfirm: () => deleteQuote(quote.id),
        })}>
          <Trash2 size={16} /> Excluir peça
        </button>
      </div>
    </div>
  )
}

function MultipleSummary({ quotes }: { quotes: QuoteRecord[] }) {
  const addQuotesToProposal = useApp((s) => s.addQuotesToProposal)
  const priced = quotes.filter((q) => canPrice(q.result))
  const total = priced.reduce((sum, q) => sum + (q.result.suggestedPrice ?? 0), 0)
  return (
    <div className="detail-inner">
      <h2>{quotes.length} peças selecionadas</h2>
      <p className="muted">Gere um orçamento com todas elas, uma unidade de cada. Você ajusta quantidades e preços depois.</p>
      <Section>
        {quotes.map((q) => (
          <Row key={q.id} label={displayName(q.job.name, 'Peça sem nome')}>
            <span className={canPrice(q.result) ? '' : 'warn'}>
              {q.result.suggestedPrice === null ? 'Sem preço — será ignorada' : money(q.result.suggestedPrice)}
            </span>
          </Row>
        ))}
        <Row label={<strong>Total (1 un. de cada)</strong>}><strong>{money(total)}</strong></Row>
      </Section>
      <div className="btn-row">
        <button className="btn primary" disabled={!priced.length} onClick={() => addQuotesToProposal(quotes, null)}>
          <FilePlus2 size={16} /> Gerar orçamento com {priced.length} peças
        </button>
        <AddToProposalMenu quotes={quotes} label="Adicionar a existente…" />
      </div>
    </div>
  )
}
