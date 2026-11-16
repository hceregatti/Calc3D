import { Box, CheckCircle2, FileText, Layers, PlusCircle, Printer, Plus, Search, Trash2 } from 'lucide-react'
import { useMemo, useState } from 'react'
import { money, calculate, canPrice, defaultJob, type PrintJob } from '../core/calculator'
import { cpfCnpjMask, currencySymbol, phoneMask } from '../core/format'
import {
  MAX_QUANTITY,
  clampQuantity,
  displayName,
  formattedNumber,
  fromCents,
  itemSubtotalCents,
  itemsTotalCents,
  toCents,
  totalCents,
  uid,
  type Proposal,
  type ProposalItem,
} from '../core/models'
import { ImageSlot } from '../components/ImageSlot'
import { Badge, Empty, Modal, NumberInput, PageHeader, Row, Section, Stepper, TextField } from '../components/ui'
import { ProposalPreview } from '../pdf/ProposalDocument'
import { useApp } from '../store'
import { BreakdownCard, PartForm, PriceCard } from './PrintJob'

export function ProposalsScreen() {
  const { proposals, proposalDraft, startNewProposal, openProposal } = useApp()

  return (
    <div className="page">
      <PageHeader title="Orçamentos">
        <button className="btn primary" onClick={startNewProposal}>
          <Plus size={16} /> Novo orçamento
        </button>
      </PageHeader>
      <div className="master-detail">
        <div className="master">
          {proposals.length === 0 && !proposalDraft ? (
            <Empty icon={FileText} title="Nenhum orçamento" text="Monte orçamentos com várias peças do histórico ou itens manuais." />
          ) : (
            <div className="list">
              {proposals.map((p) => (
                <div key={p.id} className={`list-row ${proposalDraft?.id === p.id ? 'selected' : ''}`} onClick={() => openProposal(p.id)}>
                  <div className="grow text">
                    <strong className="ellipsis">
                      {formattedNumber(p) && <span className="muted">Nº {formattedNumber(p)} · </span>}
                      {displayName(p.title, 'Orçamento sem título')}
                    </strong>
                    <small className="muted">
                      {p.items.length} {p.items.length === 1 ? 'item' : 'itens'} ·{' '}
                      {new Date(p.updatedAt).toLocaleDateString('pt-BR', { dateStyle: 'medium' })}
                    </small>
                  </div>
                  <span className="num muted">{money(fromCents(totalCents(p)))}</span>
                </div>
              ))}
            </div>
          )}
        </div>
        <div className="detail">
          {proposalDraft ? (
            <ProposalEditor proposal={proposalDraft} key={proposalDraft.id} />
          ) : (
            <Empty icon={FileText} title="Crie ou selecione um orçamento" text="Monte orçamentos com várias peças do histórico ou itens manuais." />
          )}
        </div>
      </div>
    </div>
  )
}

function ProposalEditor({ proposal }: { proposal: Proposal }) {
  const { updateDraft, saveDraft, deleteProposal, askConfirm, proposals, quotes, addQuotesToDraft } = useApp()
  const unsaved = useApp((s) => s.proposalHasUnsavedChanges())
  const isSaved = proposals.some((p) => p.id === proposal.id)
  const [calculating, setCalculating] = useState(false)
  const [picking, setPicking] = useState(false)
  const [previewing, setPreviewing] = useState(false)

  const set = <K extends keyof Proposal>(key: K) => (value: Proposal[K]) => updateDraft((p) => void (p[key] = value))

  return (
    <div className="detail-inner editor">
      <Section title="Orçamento">
        <Row label="Número">{formattedNumber(proposal) ? `Nº ${formattedNumber(proposal)}` : <span className="muted">Definido ao salvar</span>}</Row>
        <TextField label="Título do orçamento" value={proposal.title} onChange={set('title')} />
        <Row label="Atualizado">{new Date(proposal.updatedAt).toLocaleString('pt-BR', { dateStyle: 'long', timeStyle: 'short' })}</Row>
      </Section>

      <Section title="Cliente">
        <div className="field-grid">
          <TextField label="Nome ou empresa" value={proposal.customerName} onChange={set('customerName')} />
          <TextField label="CPF / CNPJ" value={proposal.customerDocument} mask={cpfCnpjMask} onChange={set('customerDocument')} />
          <TextField label="Telefone / e-mail" value={proposal.customerContact} mask={phoneMask} onChange={set('customerContact')} />
          <TextField label="Endereço" value={proposal.customerAddress} onChange={set('customerAddress')} />
        </div>
      </Section>

      <Section
        title="Peças e itens"
        footer="Os valores ficam copiados no orçamento: alterar ou excluir a peça no histórico não muda este documento."
      >
        {proposal.items.length === 0 && (
          <Empty icon={Layers} title="Nenhuma peça" text="Calcule uma nova peça ou adicione peças do histórico." />
        )}
        {proposal.items.map((item) => (
          <ItemEditor key={item.id} item={item} />
        ))}
        <div className="btn-row wrap">
          <button className="btn" onClick={() => setCalculating(true)} title="Abre o cálculo completo da peça e adiciona o resultado ao orçamento">
            <PlusCircle size={16} /> Calcular nova peça…
          </button>
          <button className="btn" disabled={!quotes.length} onClick={() => setPicking(true)}>
            <Layers size={16} /> Adicionar do histórico…
          </button>
          <button className="btn ghost" onClick={() => updateDraft((p) => void p.items.push({
            id: uid(), name: '', details: '', quantity: 1, unitPriceCents: 0, sourceQuoteId: null, imageId: null,
          }))}>
            <Plus size={16} /> Item manual
          </button>
        </div>
      </Section>

      <Section>
        <Row label="Subtotal dos itens">{money(fromCents(itemsTotalCents(proposal)))}</Row>
        <Row label="Frete">
          <span className="unit">{currencySymbol()}</span>
          <NumberInput kind="money" max={1_000_000_000} value={fromCents(proposal.shippingCents)} onChange={(v) => set('shippingCents')(toCents(v))} width={120} ariaLabel="Frete" />
        </Row>
        <Row label="Desconto">
          <span className="unit">{currencySymbol()}</span>
          <NumberInput kind="money" max={1_000_000_000} value={fromCents(proposal.discountCents)} onChange={(v) => set('discountCents')(toCents(v))} width={120} ariaLabel="Desconto" />
        </Row>
        <Row label={<strong className="big">Total do orçamento</strong>}>
          <strong className="big num">{money(fromCents(totalCents(proposal)))}</strong>
        </Row>
      </Section>

      <Section
        title="Condições"
        footer="Novos orçamentos começam com os padrões de “Personalizar orçamento”. Campos vazios não aparecem no PDF."
      >
        <Row label="Validade">
          <Stepper label="Validade em dias" value={proposal.validityDays} min={0} max={365} onChange={set('validityDays')} />
          <span className="unit">{proposal.validityDays === 0 ? 'sem validade' : 'dias'}</span>
        </Row>
        <TextField label="Forma de pagamento" value={proposal.paymentTerms} onChange={set('paymentTerms')} multiline rows={2} />
        <TextField label="Prazo de entrega" value={proposal.deliveryTime} onChange={set('deliveryTime')} multiline rows={2} />
        <TextField label="Observações" value={proposal.notes} onChange={set('notes')} multiline rows={3} />
      </Section>

      <div className="editor-bar">
        {isSaved && (
          <button className="btn danger-text" onClick={() => askConfirm({
            title: 'Excluir orçamento?',
            message: `${proposal.title ? `"${proposal.title}"` : 'Este orçamento'} será removido permanentemente.`,
            confirmLabel: 'Excluir',
            destructive: true,
            onConfirm: () => deleteProposal(proposal.id),
          })}>
            <Trash2 size={16} /> Excluir
          </button>
        )}
        <span className="grow" />
        <button
          className="btn"
          disabled={!proposal.items.length || !isSaved || unsaved}
          title={!isSaved || unsaved ? 'Salve o orçamento antes de gerar o PDF' : 'Visualizar e salvar em PDF'}
          onClick={() => setPreviewing(true)}
        >
          <Printer size={16} /> Gerar PDF
        </button>
        <button className="btn primary" disabled={!unsaved} onClick={saveDraft}>
          <CheckCircle2 size={16} /> Salvar orçamento
        </button>
      </div>

      {calculating && <PartCalculatorModal onClose={() => setCalculating(false)} />}
      {picking && (
        <PartsPicker
          onClose={() => setPicking(false)}
          onAdd={(ids) => {
            addQuotesToDraft(quotes.filter((q) => ids.includes(q.id)))
            setPicking(false)
          }}
        />
      )}
      {previewing && <ProposalPreview proposal={proposal} onClose={() => setPreviewing(false)} />}
    </div>
  )
}

function ItemEditor({ item }: { item: ProposalItem }) {
  const { updateItem, updateDraft } = useApp()
  return (
    <div className="item-editor">
      <ImageSlot imageId={item.imageId} kind="product" onChange={(imageId) => updateItem(item.id, { imageId })} />
      <div className="item-fields">
        <div className="item-top">
          <input className="input item-name" value={item.name} placeholder="Peça ou item" onChange={(e) => updateItem(item.id, { name: e.target.value })} />
          <button className="icon-btn danger-text" title="Remover do orçamento" aria-label="Remover do orçamento"
            onClick={() => updateDraft((p) => void (p.items = p.items.filter((i) => i.id !== item.id)))}>
            <Trash2 size={16} />
          </button>
        </div>
        <input className="input subtle" value={item.details} placeholder="Descrição (opcional)" onChange={(e) => updateItem(item.id, { details: e.target.value })} />
        <div className="item-numbers">
          <label className="inline">
            Qtd.
            <Stepper label="Quantidade" value={item.quantity} min={1} max={MAX_QUANTITY} onChange={(q) => updateItem(item.id, { quantity: clampQuantity(q) })} />
          </label>
          <label className="inline">
            Unitário {currencySymbol()}
            <NumberInput kind="money" max={1_000_000_000} value={fromCents(item.unitPriceCents)} width={120} ariaLabel="Preço unitário"
              onChange={(v) => updateItem(item.id, { unitPriceCents: toCents(v) })} />
          </label>
          <span className="grow" />
          <strong className="num">{money(fromCents(itemSubtotalCents(item)))}</strong>
        </div>
      </div>
    </div>
  )
}

function PartCalculatorModal({ onClose }: { onClose: () => void }) {
  const { settings, saveQuote, addQuotesToDraft } = useApp()
  const [job, setJobState] = useState<PrintJob>({ ...defaultJob })
  const [saveToHistory, setSaveToHistory] = useState(true)
  const result = useMemo(() => calculate(settings, job), [settings, job])

  return (
    <Modal
      wide
      onClose={onClose}
      title={
        <div className="modal-title">
          <Badge icon={Box} color="#ff9f0a" size={28} />
          <div>
            <strong>Calcular peça para o orçamento</strong>
            <small className="muted">Usa os parâmetros fixos atuais. O preço sugerido entra como item do orçamento.</small>
          </div>
        </div>
      }
      footer={
        <>
          <label className="checkbox">
            <input type="checkbox" checked={saveToHistory} onChange={(e) => setSaveToHistory(e.target.checked)} />
            Salvar também no histórico de peças
          </label>
          <span className="grow" />
          <button className="btn" onClick={onClose}>Cancelar</button>
          <button className="btn primary" disabled={!canPrice(result)} onClick={() => {
            const quote = saveToHistory
              ? saveQuote(job)
              : { id: uid(), savedAt: new Date().toISOString(), job, settings, result }
            addQuotesToDraft([quote])
            onClose()
          }}>
            <PlusCircle size={16} /> Adicionar ao orçamento
          </button>
        </>
      }
    >
      <div className="split in-modal">
        <div className="split-main">
          <PartForm job={job} setJob={(patch) => setJobState((j) => ({ ...j, ...patch }))} settings={settings} />
        </div>
        <aside className="split-side">
          <PriceCard result={result} />
          <BreakdownCard result={result} />
        </aside>
      </div>
    </Modal>
  )
}

function PartsPicker({ onClose, onAdd }: { onClose: () => void; onAdd: (ids: string[]) => void }) {
  const quotes = useApp((s) => s.quotes)
  const [search, setSearch] = useState('')
  const [selection, setSelection] = useState<string[]>([])
  const term = search.trim().toLowerCase()
  const visible = term ? quotes.filter((q) => q.job.name.toLowerCase().includes(term)) : quotes
  const chosen = selection.filter((id) => quotes.some((q) => q.id === id))

  return (
    <Modal
      title="Adicionar peças do histórico"
      onClose={onClose}
      footer={
        <>
          <button className="link" onClick={() => setSelection(chosen.length ? [] : visible.filter((q) => canPrice(q.result)).map((q) => q.id))}>
            {chosen.length ? 'Limpar seleção' : 'Selecionar todas'}
          </button>
          <span className="grow" />
          <button className="btn" onClick={onClose}>Cancelar</button>
          <button className="btn primary" disabled={!chosen.length} onClick={() => onAdd(chosen)}>
            {chosen.length > 1 ? `Adicionar ${chosen.length} peças` : 'Adicionar'}
          </button>
        </>
      }
    >
      <div className="search">
        <Search size={14} />
        <input className="input" placeholder="Buscar peça" value={search} autoFocus onChange={(e) => setSearch(e.target.value)} />
      </div>
      <div className="list picker">
        {visible.map((q) => {
          const enabled = canPrice(q.result)
          return (
            <label key={q.id} className={`list-row ${enabled ? '' : 'disabled'}`}>
              <input
                type="checkbox"
                disabled={!enabled}
                checked={selection.includes(q.id)}
                onChange={(e) => setSelection(e.target.checked ? [...selection, q.id] : selection.filter((s) => s !== q.id))}
              />
              <span className="grow text">
                <span className="ellipsis">{displayName(q.job.name, 'Peça sem nome')}</span>
                <small className="muted">{new Date(q.savedAt).toLocaleString('pt-BR', { dateStyle: 'medium', timeStyle: 'short' })}</small>
              </span>
              <span className="num">{q.result.suggestedPrice === null ? 'Sem preço' : money(q.result.suggestedPrice)}</span>
            </label>
          )
        })}
        {!visible.length && <p className="muted center pad">Nenhuma peça encontrada.</p>}
      </div>
    </Modal>
  )
}
