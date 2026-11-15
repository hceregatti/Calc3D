import { Image as ImageIcon, Printer } from 'lucide-react'
import { useEffect } from 'react'
import { createPortal } from 'react-dom'
import { brl } from '../core/calculator'
import {
  formattedNumber,
  fromCents,
  itemSubtotalCents,
  itemsTotalCents,
  totalCents,
  validUntil,
  type CompanyProfile,
  type Proposal,
} from '../core/models'
import { Modal } from '../components/ui'
import { useImage } from '../images'
import { useApp } from '../store'

const longDate = (d: Date) => d.toLocaleDateString('pt-BR', { dateStyle: 'long' })
const shortDate = (d: Date) => d.toLocaleDateString('pt-BR')

/** Orçamento no formato A4, usado na visualização e na impressão/PDF. */
export function ProposalDocument({ proposal, company }: { proposal: Proposal; company: CompanyProfile }) {
  const logo = useImage(company.logoImageId)
  const number = formattedNumber(proposal)
  const until = validUntil(proposal)
  const title = proposal.title.trim() || 'Orçamento'
  const name = company.companyName.trim()
  const contactRows = [
    [company.phone, company.whatsapp.trim() && `WhatsApp ${company.whatsapp.trim()}`],
    [company.email, company.website],
    [company.instagram],
  ]
    .map((row) => row.map((v) => (v || '').trim()).filter(Boolean).join('  ·  '))
    .filter(Boolean)
  const customer = [
    ['Cliente', proposal.customerName],
    ['CPF/CNPJ', proposal.customerDocument],
    ['Contato', proposal.customerContact],
    ['Endereço', proposal.customerAddress],
  ].filter(([, v]) => v.trim())
  const hasAdjustments = proposal.discountCents > 0 || proposal.shippingCents > 0
  const conditions = [
    ['Forma de pagamento', proposal.paymentTerms.trim()],
    ['Prazo de entrega', proposal.deliveryTime.trim()],
    ['Validade da proposta', until ? `${proposal.validityDays} dias, até ${longDate(until)}.` : ''],
    ['Observações', proposal.notes.trim()],
  ].filter(([, v]) => v)
  const showPhotos = company.showProductPhotos
  const hasHeader = logo || name || company.document.trim() || company.address.trim() || contactRows.length

  return (
    <article className="doc" style={{ ['--accent' as string]: company.accentColor }}>
      <div className="doc-band" />
      {hasHeader && (
        <>
          <header className="doc-company">
            {logo ? <img className="doc-logo" src={logo} alt="" /> : name && <div className="doc-name-big">{name}</div>}
            <div className="doc-company-info">
              {logo && name && <strong>{name}</strong>}
              {company.document.trim() && <span>{company.document.trim()}</span>}
              {company.address.split('\n').filter((l) => l.trim()).map((l, i) => <span key={i}>{l.trim()}</span>)}
              {contactRows.map((r, i) => <span key={i}>{r}</span>)}
            </div>
          </header>
          <hr className="doc-accent-rule" />
        </>
      )}

      <div className="doc-heading">
        <div>
          <div className="doc-label">ORÇAMENTO{number && <>&nbsp;&nbsp;Nº {number}</>}</div>
          <h1>{title}</h1>
        </div>
        <div className="doc-dates">
          <span>Emissão: {longDate(new Date(proposal.updatedAt))}</span>
          {until && <strong>Válido até {shortDate(until)} ({proposal.validityDays} dias)</strong>}
        </div>
      </div>

      {customer.length > 0 && (
        <div className="doc-customer">
          <div className="doc-label small">PARA</div>
          <dl>
            {customer.map(([label, value]) => (
              <div key={label}>
                <dt>{label}</dt>
                <dd className={label === 'Cliente' ? 'strong' : ''}>{value}</dd>
              </div>
            ))}
          </dl>
        </div>
      )}

      <table className="doc-items">
        <thead>
          <tr>
            {showPhotos && <th className="photo-col" />}
            <th className="left">PRODUTO</th>
            <th>QTD.</th>
            <th>UNITÁRIO</th>
            <th>SUBTOTAL</th>
          </tr>
        </thead>
        <tbody>
          {proposal.items.map((item) => (
            <tr key={item.id}>
              {showPhotos && (
                <td className="photo-col">
                  <DocPhoto imageId={item.imageId} />
                </td>
              )}
              <td className="left">
                <div className="doc-item-name">{item.name.trim() || 'Item sem nome'}</div>
                {item.details.trim() && <div className="doc-item-details">{item.details.trim()}</div>}
              </td>
              <td>{item.quantity}</td>
              <td>{brl(fromCents(item.unitPriceCents))}</td>
              <td className="strong">{brl(fromCents(itemSubtotalCents(item)))}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <div className="doc-totals">
        {hasAdjustments && (
          <dl>
            <div><dt>Subtotal</dt><dd>{brl(fromCents(itemsTotalCents(proposal)))}</dd></div>
            {proposal.shippingCents > 0 && <div><dt>Frete</dt><dd>{brl(fromCents(proposal.shippingCents))}</dd></div>}
            {proposal.discountCents > 0 && <div><dt>Desconto</dt><dd>− {brl(fromCents(proposal.discountCents))}</dd></div>}
          </dl>
        )}
        <div className="doc-total-box">
          <span>TOTAL</span>
          <strong>{brl(fromCents(totalCents(proposal)))}</strong>
        </div>
      </div>

      {conditions.length > 0 && (
        <section className="doc-conditions">
          <div className="doc-label">CONDIÇÕES</div>
          {conditions.map(([label, value]) => (
            <div key={label} className="doc-condition">
              <strong>{label}</strong>
              <p>{value}</p>
            </div>
          ))}
        </section>
      )}

      {company.responsibleName.trim() && (
        <div className="doc-signature">
          <div className="doc-signature-line" />
          <strong>{company.responsibleName.trim()}</strong>
          {name && <span>{name}</span>}
        </div>
      )}

      <footer className="doc-footer-screen">
        <span>{footerText(company)}</span>
      </footer>
    </article>
  )
}

function DocPhoto({ imageId }: { imageId: string | null }) {
  const url = useImage(imageId)
  return url ? (
    <img className="doc-photo" src={url} alt="" />
  ) : (
    <div className="doc-photo placeholder">
      <ImageIcon size={20} strokeWidth={1.6} />
    </div>
  )
}

const footerText = (c: CompanyProfile) =>
  c.footerText.trim() || [c.companyName, c.phone, c.email].map((v) => v.trim()).filter(Boolean).join('  ·  ')

const cssString = (s: string) => `"${s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' ')}"`

/** Visualização com botão para imprimir ou salvar em PDF pelo navegador. */
export function ProposalPreview({
  proposal,
  company: override,
  onClose,
}: {
  proposal: Proposal
  company?: CompanyProfile
  onClose: () => void
}) {
  const savedCompany = useApp((s) => s.savedCompany)
  const company = override ?? savedCompany

  useEffect(() => {
    // Rodapé e número de página em todas as folhas (Chrome/Edge 131+).
    const style = document.createElement('style')
    style.textContent = `@page { size: A4; margin: 14mm 14mm 16mm;
      @bottom-left { content: ${cssString(footerText(company))}; font: 8pt system-ui, sans-serif; color: #6b6b6b; }
      @bottom-right { content: "Página " counter(page); font: 8pt system-ui, sans-serif; color: #6b6b6b; } }`
    document.head.appendChild(style)
    document.body.classList.add('printing-proposal')
    return () => {
      style.remove()
      document.body.classList.remove('printing-proposal')
    }
  }, [company])

  const print = () => {
    // O navegador usa o título da página como nome sugerido do PDF.
    const previous = document.title
    const number = formattedNumber(proposal)
    document.title = `${number ? `Orcamento ${number} - ` : ''}${proposal.title.trim() || 'Orcamento'}`
    const restore = () => {
      document.title = previous
      window.removeEventListener('afterprint', restore)
    }
    window.addEventListener('afterprint', restore)
    window.print()
  }

  return (
    <>
      <Modal
        wide
        title="Visualizar orçamento"
        onClose={onClose}
        footer={
          <>
            <small className="muted">Na janela de impressão, escolha “Salvar como PDF” e desmarque “Cabeçalhos e rodapés”.</small>
            <span className="grow" />
            <button className="btn" onClick={onClose}>Fechar</button>
            <button className="btn primary" onClick={print}>
              <Printer size={16} /> Imprimir / Salvar PDF
            </button>
          </>
        }
      >
        <div className="paper-wrap">
          <div className="paper">
            <ProposalDocument proposal={proposal} company={company} />
          </div>
        </div>
      </Modal>
      {createPortal(
        <div id="print-root">
          <ProposalDocument proposal={proposal} company={company} />
        </div>,
        document.body,
      )}
    </>
  )
}
