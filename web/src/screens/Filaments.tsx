import { BarChart3, Cylinder, Copy, ExternalLink, Plus, Search, Tag, Trash2, Thermometer, Scale, ShoppingCart, StickyNote } from 'lucide-react'
import { pricePerBulk, weight } from '../core/format'
import {
  MATERIALS,
  TYPICAL_PROFILE,
  filamentDisplayName,
  filamentPricePerGram,
  isRunningLow,
  purchaseLink,
  remainingFraction,
  searchUrl,
  type Filament,
  type Material,
} from '../core/filament'
import { Empty, NumberField, PageHeader, Row, Section, TextField } from '../components/ui'
import { useApp } from '../store'

export function FilamentsScreen() {
  const { filaments, selectedFilamentId, selectFilament, addFilament } = useApp()
  const selected = filaments.find((f) => f.id === selectedFilamentId) ?? null

  return (
    <div className="page">
      <PageHeader title="Filamentos">
        <button className="btn primary" onClick={addFilament}>
          <Plus size={16} /> Novo filamento
        </button>
      </PageHeader>
      <div className="master-detail">
        <div className="master">
          {filaments.length === 0 ? (
            <Empty icon={Cylinder} title="Nenhum filamento" text="Cadastre os rolos que você tem: marca, peso, valor e parâmetros de impressão.">
              <button className="btn" onClick={addFilament}>Adicionar filamento</button>
            </Empty>
          ) : (
            <div className="list">
              {filaments.map((f) => (
                <div key={f.id} className={`list-row ${f.id === selectedFilamentId ? 'selected' : ''}`} onClick={() => selectFilament(f.id)}>
                  <span className="swatch" style={{ background: f.colorHex }} aria-hidden />
                  <div className="grow text">
                    <strong className="ellipsis">{filamentDisplayName(f) || 'Novo filamento'}</strong>
                    <small className="muted ellipsis">
                      {weight(f.remainingWeight)} restantes · {pricePerBulk(filamentPricePerGram(f))}
                      {isRunningLow(f) && <strong className="warn"> · Acabando</strong>}
                    </small>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
        <div className="detail">
          {selected ? (
            <FilamentEditor key={selected.id} filament={selected} />
          ) : filaments.length ? (
            <Empty icon={Cylinder} title="Selecione um filamento" text="Escolha um rolo da lista para ver e editar a ficha." />
          ) : null}
        </div>
      </div>
    </div>
  )
}

function FilamentEditor({ filament: f }: { filament: Filament }) {
  const updateFilament = useApp((s) => s.updateFilament)
  const duplicateFilament = useApp((s) => s.duplicateFilament)
  const deleteFilament = useApp((s) => s.deleteFilament)
  const askConfirm = useApp((s) => s.askConfirm)
  const weightUnit = useApp((s) => s.settings.weightUnit)
  const set = (patch: Partial<Filament>) => updateFilament(f.id, patch)
  const link = purchaseLink(f)
  const open = (url: string) => window.open(url, '_blank', 'noopener,noreferrer')

  return (
    <div className="detail-inner">
      <h2>{filamentDisplayName(f) || 'Novo filamento'}</h2>

      <Section title="Identificação" icon={Tag} color="#5e5ce6">
        <TextField label="Marca" value={f.brand} placeholder="Ex.: Voolt3D" onChange={(brand) => set({ brand })} />
        <TextField label="Linha / nome" value={f.name} placeholder="Ex.: Silk, Basic" onChange={(name) => set({ name })} />
        <Row label="Material">
          <select className="input" style={{ width: 220 }} aria-label="Material" value={f.material}
            onChange={(e) => set({ material: e.target.value as Material })}>
            {MATERIALS.map((m) => <option key={m}>{m}</option>)}
          </select>
        </Row>
        <Row label="Cor">
          <input className="input" style={{ width: 160 }} aria-label="Nome da cor" placeholder="Ex.: Preto" value={f.colorName}
            onChange={(e) => set({ colorName: e.target.value })} />
          <input type="color" aria-label="Escolher cor" value={f.colorHex} onChange={(e) => set({ colorHex: e.target.value })} />
        </Row>
      </Section>

      <Section title="Rolo e preço" icon={Scale} color="#30d158">
        <NumberField label="Preço do rolo" kind="money" value={f.price} onChange={(price) => set({ price })} />
        <NumberField label="Peso líquido" kind="weight" value={f.netWeight} onChange={(netWeight) => set({ netWeight })} />
        <NumberField label="Peso restante" kind="weight" value={f.remainingWeight} hint="Quanto ainda há no rolo" onChange={(remainingWeight) => set({ remainingWeight })} />
        <NumberField label="Diâmetro" unit="mm" value={f.diameter} hint="1,75 ou 2,85" onChange={(diameter) => set({ diameter })} />
        <Row label="Preço por unidade de peso">{pricePerBulk(filamentPricePerGram(f), weightUnit)}</Row>
        <progress className="spool-bar" style={{ accentColor: f.colorHex }} value={remainingFraction(f)} max={1} aria-label="Restante do rolo" />
      </Section>

      <Section title="Impressão" icon={Thermometer} color="#ff9f0a">
        <NumberField label="Bico (mínimo)" unit="°C" max={500} value={f.nozzleTempMin} onChange={(nozzleTempMin) => set({ nozzleTempMin })} />
        <NumberField label="Bico (máximo)" unit="°C" max={500} value={f.nozzleTempMax} onChange={(nozzleTempMax) => set({ nozzleTempMax })} />
        <NumberField label="Mesa" unit="°C" max={200} value={f.bedTemp} onChange={(bedTemp) => set({ bedTemp })} />
        <NumberField label="Densidade" unit="g/cm³" value={f.density} onChange={(density) => set({ density })} />
        <div className="btn-row">
          <button className="link" onClick={() => set(TYPICAL_PROFILE[f.material])}>Usar valores típicos de {f.material}</button>
        </div>
      </Section>

      <Section
        title="Compra"
        icon={ShoppingCart}
        color="#0a84ff"
        footer="“Buscar na web” abre uma pesquisa com marca, material, cor e peso. Cole aqui o link do anúncio escolhido."
      >
        <TextField label="Loja" value={f.store} placeholder="Ex.: Mercado Livre" onChange={(store) => set({ store })} />
        <TextField label="Link de compra" value={f.purchaseUrl} placeholder="https://…" onChange={(purchaseUrl) => set({ purchaseUrl })} />
        {f.purchaseUrl && !link && <p className="feedback warn">Link inválido: use um endereço http ou https.</p>}
        <div className="btn-row">
          <button className="btn" onClick={() => open(searchUrl(f))}><Search size={16} /> Buscar na web</button>
          <button className="btn" disabled={!link} onClick={() => link && open(link)}><ExternalLink size={16} /> Abrir link</button>
        </div>
      </Section>

      <ConsumptionHistory filamentId={f.id} />

      <Section title="Observações" icon={StickyNote} color="#8e8e93">
        <TextField label="Observações" multiline rows={4} value={f.notes} onChange={(notes) => set({ notes })} />
      </Section>

      <div className="btn-row">
        <button className="btn" onClick={() => duplicateFilament(f.id)}><Copy size={16} /> Duplicar</button>
        <span className="grow" />
        <button className="btn danger-text" onClick={() => askConfirm({
          title: 'Excluir filamento?',
          message: 'Peças já calculadas mantêm o preço usado na época.',
          confirmLabel: 'Excluir',
          destructive: true,
          onConfirm: () => deleteFilament(f.id),
        })}>
          <Trash2 size={16} /> Excluir
        </button>
      </div>
    </div>
  )
}

/** Baixas já feitas por orçamentos neste rolo, das mais recentes para as mais antigas. */
function ConsumptionHistory({ filamentId }: { filamentId: string }) {
  const proposals = useApp((s) => s.proposals)
  const entries = proposals
    .flatMap((p) => p.stockDeductions.filter((d) => d.filamentId === filamentId).map((d) => ({ p, d })))
    .sort((a, b) => b.d.date.localeCompare(a.d.date))
  if (!entries.length) return null
  return (
    <Section title="Consumo" icon={BarChart3} color="#ff375f" footer="Baixas feitas por orçamentos neste rolo.">
      {entries.map(({ p, d }) => (
        <Row key={`${p.id}-${d.date}`} label={p.title.trim() || 'Orçamento sem título'} hint={new Date(d.date).toLocaleString('pt-BR', { dateStyle: 'medium', timeStyle: 'short' })}>
          −{weight(d.grams)}
        </Row>
      ))}
    </Section>
  )
}
