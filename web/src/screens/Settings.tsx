import {
  AlertCircle,
  Box,
  Building2,
  CheckCircle2,
  CircleDot,
  Database,
  Download,
  Eye,
  FileCog,
  Globe,
  Gauge,
  Image as ImageIcon,
  Palette,
  Percent,
  Phone,
  Printer,
  RotateCcw,
  Upload,
  Zap,
} from 'lucide-react'
import { useRef, useState } from 'react'
import { exportBackup, importBackup } from '../backup'
import { money, derived } from '../core/calculator'
import { CURRENCIES, WEIGHT_UNITS, cpfCnpjMask, phoneMask, type CurrencyCode, type WeightUnitId } from '../core/format'
import { defaultCompany, newItem, newProposal, toCents } from '../core/models'
import { ImageSlot } from '../components/ImageSlot'
import { NumberField, NumberInput, PageHeader, Row, Section, Stepper, TextField } from '../components/ui'
import { ProposalPreview } from '../pdf/ProposalDocument'
import { useApp } from '../store'

function SaveStatus({ unsaved, savedLabel }: { unsaved: boolean; savedLabel: string }) {
  return (
    <span className={`status ${unsaved ? 'warn' : 'muted'}`}>
      {unsaved ? <AlertCircle size={14} /> : <CheckCircle2 size={14} />}
      {unsaved ? 'Alterações não salvas' : savedLabel}
    </span>
  )
}

export function ShopSettingsScreen() {
  const { settings: s, savedSettings, setSettings, saveSettings, resetSettings } = useApp()
  const unsaved = JSON.stringify(s) !== JSON.stringify(savedSettings)
  const d = derived(s)
  type NumericKey = { [K in keyof typeof s]: (typeof s)[K] extends number ? K : never }[keyof typeof s]
  const field = (key: NumericKey) => ({ value: s[key], onChange: (v: number) => setSettings({ [key]: v }) })

  return (
    <div className="page narrow">
      <PageHeader title="Parâmetros fixos">
        <SaveStatus unsaved={unsaved} savedLabel="Parâmetros salvos" />
        <button className="btn" onClick={resetSettings} title="Volta todos os parâmetros aos valores padrão">
          <RotateCcw size={16} /> Restaurar padrões
        </button>
        <button className="btn primary" disabled={!unsaved} onClick={saveSettings}>
          <CheckCircle2 size={16} /> Salvar
        </button>
      </PageHeader>

      <Section title="Moeda e unidades" icon={Globe} color="#30b0c7"
        footer="Muda só a exibição e a digitação: valores não são convertidos entre moedas. Pesos ficam guardados em gramas e são convertidos para a unidade escolhida.">
        <Row label="Moeda">
          <select className="input" style={{ width: 220 }} aria-label="Moeda" value={s.currency}
            onChange={(e) => setSettings({ currency: e.target.value as CurrencyCode })}>
            {(Object.keys(CURRENCIES) as CurrencyCode[]).map((code) => (
              <option key={code} value={code}>{CURRENCIES[code].title}</option>
            ))}
          </select>
        </Row>
        <Row label="Unidade de peso">
          <select className="input" style={{ width: 220 }} aria-label="Unidade de peso" value={s.weightUnit}
            onChange={(e) => setSettings({ weightUnit: e.target.value as WeightUnitId })}>
            {(Object.keys(WEIGHT_UNITS) as WeightUnitId[]).map((id) => (
              <option key={id} value={id}>{WEIGHT_UNITS[id].title}</option>
            ))}
          </select>
        </Row>
      </Section>

      <Section title="Quanto custa uma hora de impressão" icon={Gauge} color="#5e5ce6"
        footer="Calculado a partir dos campos abaixo. As perdas por falha são somadas em cada impressão.">
        <Row label={<><span className="dot" style={{ background: '#ff9f0a' }} /> Energia</>}>{money(d.energyCostPerHour)}/h</Row>
        <Row label={<><span className="dot" style={{ background: '#bf5af2' }} /> Depreciação</>}>{money(d.depreciationPerHour)}/h</Row>
        <Row label={<><span className="dot" style={{ background: '#8e8e93' }} /> Manutenção</>}>{money(d.maintenancePerHour)}/h</Row>
        <Row label={<><span className="dot" style={{ background: '#30b0c7' }} /> Custos fixos</>}>{money(d.overheadPerHour)}/h</Row>
        <Row label={<strong>Total por hora de máquina</strong>}><strong>{money(d.machineCostPerHour)}/h</strong></Row>
      </Section>

      <Section title="Filamento padrão" icon={CircleDot} color="#ff9f0a">
        <NumberField label="Preço do rolo" kind="money" {...field('spoolPrice')} />
        <NumberField label="Peso do rolo" kind="weight" {...field('spoolWeight')} />
      </Section>

      <Section title="Energia" icon={Zap} color="#ffd60a">
        <NumberField label="Consumo médio" unit="W" hint="PLA ~100–150 W; ABS/ASA ~200–300 W. Meça com uma tomada medidora." {...field('powerWatts')} />
        <NumberField label="Tarifa de energia" kind="money" unit="/kWh" hint="Valor final da conta: impostos + bandeira" {...field('energyTariff')} />
      </Section>

      <Section title="Máquina" icon={Printer} color="#0a84ff">
        <NumberField label="Preço da impressora" kind="money" {...field('printerPrice')} />
        <NumberField label="Valor de revenda" kind="money" {...field('resaleValue')} />
        <NumberField label="Vida útil" unit="h" {...field('lifetimeHours')} />
        <NumberField label="Manutenção por ano" kind="money" hint="Bicos, mesa/PEI, correias, ventoinhas, lubrificação" {...field('maintenancePerYear')} />
        <NumberField label="Horas impressas por ano" unit="h" {...field('hoursPerYear')} />
      </Section>

      <Section title="Mão de obra e embalagem" icon={Box} color="#a2845e">
        <NumberField label="Valor da sua hora" kind="money" unit="/h" {...field('laborRate')} />
        <NumberField label="Embalagem por peça" kind="money" {...field('packagingPerPart')} />
      </Section>

      <Section title="Custos fixos e falhas" icon={Building2} color="#ff453a">
        <NumberField label="Custos fixos mensais" kind="money" hint="Aluguel, software, internet, contador, DAS" {...field('fixedCostsPerMonth')} />
        <NumberField label="Horas impressas por mês" unit="h" {...field('hoursPerMonth')} />
        <NumberField label="Taxa de falha" unit="%" max={90} hint="Típico: 5–15%. Registre suas falhas por um mês." {...field('failureRatePercent')} />
      </Section>

      <Section title="Encargos de venda" icon={Percent} color="#30d158">
        <NumberField label="Impostos" unit="%" max={100} hint="Ex.: Simples Nacional ~6%" {...field('taxPercent')} />
        <NumberField label="Taxa marketplace/cartão" unit="%" max={100} {...field('marketplaceFeePercent')} />
        <NumberField label="Taxa fixa por venda" kind="money" hint="Shopee/Mercado Livre cobram um valor fixo por item" {...field('fixedFeePerSale')} />
      </Section>

      <BackupSection />
    </div>
  )
}

function BackupSection() {
  const { askConfirm, showToast } = useApp()
  const input = useRef<HTMLInputElement>(null)
  return (
    <Section title="Backup dos dados" icon={Database} color="#64d2ff"
      footer="Os dados ficam só neste navegador. Exporte um backup para guardar ou levar para outro computador; importar substitui tudo o que está aqui.">
      <div className="btn-row wrap">
        <button className="btn" onClick={() => exportBackup().catch(() => showToast('Não foi possível exportar.', 'error'))}>
          <Download size={16} /> Exportar backup
        </button>
        <button className="btn" onClick={() => input.current?.click()}>
          <Upload size={16} /> Importar backup…
        </button>
        <input ref={input} type="file" accept="application/json,.json" hidden onChange={(e) => {
          const file = e.target.files?.[0]
          e.target.value = ''
          if (!file) return
          askConfirm({
            title: 'Importar backup?',
            message: 'Parâmetros, dados da empresa, peças e orçamentos deste navegador serão substituídos pelos do arquivo.',
            confirmLabel: 'Importar e substituir',
            destructive: true,
            onConfirm: () => importBackup(file)
              .then(() => showToast('Backup importado ✔'))
              .catch((err: Error) => showToast(err.message, 'error')),
          })
        }} />
      </div>
    </Section>
  )
}

export function CompanyScreen() {
  const { company: c, savedCompany, setCompany, saveCompany, resetCompanyConditions } = useApp()
  const unsaved = JSON.stringify(c) !== JSON.stringify(savedCompany)
  const [previewing, setPreviewing] = useState(false)
  const text = (key: keyof typeof c) => ({ value: String(c[key] ?? ''), onChange: (v: string) => setCompany({ [key]: v }) })

  const sample = () => {
    const p = newProposal(c, 'Orçamento de exemplo')
    p.number = c.nextProposalNumber
    p.customerName = 'Cliente Exemplo'
    p.customerContact = '(11) 90000-0000 · cliente@exemplo.com'
    p.items = [
      newItem({ name: 'Suporte articulado', details: 'PLA preto, acabamento fosco', quantity: 2, unitPrice: 45.9 }),
      newItem({ name: 'Miniatura personalizada', details: 'Resina, pintada à mão', quantity: 1, unitPrice: 120 }),
    ]
    p.shippingCents = toCents(25)
    return p
  }

  return (
    <div className="page narrow">
      <PageHeader title="Personalizar orçamento">
        <SaveStatus unsaved={unsaved} savedLabel="Dados salvos" />
        <button className="btn" onClick={() => setPreviewing(true)} title="Gera um orçamento de exemplo com estes dados">
          <Eye size={16} /> Pré-visualizar
        </button>
        <button className="btn primary" disabled={!unsaved} onClick={saveCompany}>
          <CheckCircle2 size={16} /> Salvar
        </button>
      </PageHeader>
      <p className="muted intro">Estes dados aparecem no cabeçalho, nas condições e no rodapé dos orçamentos em PDF.</p>

      <Section title="Logo" icon={ImageIcon} color="#ff375f">
        <div className="logo-row">
          <ImageSlot imageId={c.logoImageId} kind="logo" width={180} height={90} label="Adicionar logo" fit="contain"
            onChange={(logoImageId) => setCompany({ logoImageId })} />
          <p className="muted">Clique ou arraste uma imagem. PNG com fundo transparente fica melhor; a imagem é reduzida automaticamente.</p>
        </div>
      </Section>

      <Section title="Empresa" icon={Building2} color="#5e5ce6">
        <div className="field-grid">
          <TextField label="Nome da empresa" placeholder="Ex.: Studio 3D Print" {...text('companyName')} />
          <TextField label="CNPJ / CPF" placeholder="00.000.000/0001-00" mask={cpfCnpjMask} {...text('document')} />
          <TextField label="Responsável (assinatura)" placeholder="Seu nome" {...text('responsibleName')} />
        </div>
      </Section>

      <Section title="Contato e endereço" icon={Phone} color="#30d158">
        <div className="field-grid">
          <TextField label="Telefone" placeholder="(11) 3000-0000" mask={phoneMask} {...text('phone')} />
          <TextField label="WhatsApp" placeholder="(11) 90000-0000" mask={phoneMask} {...text('whatsapp')} />
          <TextField label="E-mail" placeholder="contato@empresa.com.br" {...text('email')} />
          <TextField label="Site" placeholder="www.empresa.com.br" {...text('website')} />
          <TextField label="Instagram" placeholder="@empresa" {...text('instagram')} />
        </div>
        <TextField label="Endereço" placeholder={'Rua, número, bairro\nCidade – UF, CEP'} multiline rows={2} {...text('address')} />
      </Section>

      <Section title="Aparência do PDF" icon={Palette} color="#bf5af2" footer="Produtos sem foto usam uma imagem padrão.">
        <Row label="Cor de destaque">
          <input type="color" className="color" value={c.accentColor} onChange={(e) => setCompany({ accentColor: e.target.value })} />
          <button className="link" onClick={() => setCompany({ accentColor: defaultCompany.accentColor })}>Padrão</button>
        </Row>
        <Row label="Mostrar fotos dos produtos no PDF">
          <input type="checkbox" className="switch" checked={c.showProductPhotos} onChange={(e) => setCompany({ showProductPhotos: e.target.checked })} />
        </Row>
        <TextField label="Rodapé" placeholder="Obrigado pela preferência!" {...text('footerText')} />
      </Section>

      <Section
        title="Padrões para novos orçamentos"
        icon={FileCog}
        color="#ff9f0a"
        action={<button className="link" onClick={resetCompanyConditions}>Restaurar textos sugeridos</button>}
        footer="A numeração é atribuída ao salvar um orçamento pela primeira vez. As condições podem ser ajustadas em cada orçamento."
      >
        <Row label="Próximo número">
          <NumberInput value={c.nextProposalNumber} digits={0} min={1} max={999999} onChange={(v) => setCompany({ nextProposalNumber: Math.round(v) })} ariaLabel="Próximo número" />
        </Row>
        <Row label="Validade">
          <Stepper label="Validade em dias" value={c.defaultValidityDays} min={0} max={365} onChange={(defaultValidityDays) => setCompany({ defaultValidityDays })} />
          <span className="unit">{c.defaultValidityDays === 0 ? 'sem validade' : 'dias'}</span>
        </Row>
        <TextField label="Forma de pagamento" multiline rows={2} {...text('defaultPaymentTerms')} />
        <TextField label="Prazo de entrega" multiline rows={2} {...text('defaultDeliveryTime')} />
        <TextField label="Observações" placeholder="Ex.: cores podem variar levemente" multiline rows={3} {...text('defaultNotes')} />
      </Section>

      {previewing && <ProposalPreview proposal={sample()} company={c} onClose={() => setPreviewing(false)} />}
    </div>
  )
}
