import {
  Cog,
  Box,
  FileText,
  Home,
  Layers,
  Paintbrush,
  type LucideIcon,
} from 'lucide-react'
import { useEffect, useId, useState, type ReactNode } from 'react'
import { useApp, type Screen } from '../store'
import { WEIGHT_UNITS, currencySymbol, formatNumber, fromGrams, liveMask, parseMasked, toGrams } from '../core/format'

export const SCREEN_INFO: Record<Screen, { title: string; subtitle: string; icon: LucideIcon; color: string }> = {
  home: { title: 'Início', subtitle: 'Visão geral e atalhos', icon: Home, color: '#0a84ff' },
  printJob: { title: 'Calcular peça', subtitle: 'Dados da impressão e preço', icon: Box, color: '#ff9f0a' },
  parts: { title: 'Peças', subtitle: 'Histórico de cálculos de peças', icon: Layers, color: '#bf5af2' },
  proposals: { title: 'Orçamentos', subtitle: 'Orçamentos com várias peças', icon: FileText, color: '#30d158' },
  company: { title: 'Personalizar orçamento', subtitle: 'Logo, empresa e condições', icon: Paintbrush, color: '#30b0c7' },
  settings: { title: 'Parâmetros fixos', subtitle: 'Máquina, energia, custos e taxas', icon: Cog, color: '#8e8e93' },
}

/** Ícone em quadrado arredondado com gradiente, no estilo dos Ajustes do macOS. */
export function Badge({ icon: Icon, color, size = 22 }: { icon: LucideIcon; color: string; size?: number }) {
  return (
    <span
      className="badge"
      aria-hidden
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.27,
        background: `linear-gradient(180deg, color-mix(in srgb, ${color} 80%, white), ${color})`,
        boxShadow: `0 ${size * 0.04}px ${size * 0.16}px color-mix(in srgb, ${color} 30%, transparent)`,
      }}
    >
      <Icon size={size * 0.58} strokeWidth={2.4} color="white" />
    </span>
  )
}

export function Section({
  title,
  icon,
  color,
  footer,
  action,
  children,
}: {
  title?: string
  icon?: LucideIcon
  color?: string
  footer?: ReactNode
  action?: ReactNode
  children: ReactNode
}) {
  return (
    <section className="section">
      {title && (
        <header className="section-header">
          {icon && color && <Badge icon={icon} color={color} size={20} />}
          <span>{title}</span>
          {action && <span className="section-action">{action}</span>}
        </header>
      )}
      <div className="section-body">{children}</div>
      {footer && <p className="section-footer">{footer}</p>}
    </section>
  )
}

export function Row({ label, hint, children }: { label: ReactNode; hint?: ReactNode; children?: ReactNode }) {
  return (
    <div className="row">
      <div className="row-label">
        <span>{label}</span>
        {hint && <small>{hint}</small>}
      </div>
      <div className="row-value">{children}</div>
    </div>
  )
}

export type NumberKind = 'decimal' | 'money' | 'weight'

/**
 * Campo numérico com máscara brasileira ao digitar (7.000,00 · 31,17).
 * `money` sempre mostra duas casas; `weight` recebe gramas e exibe na unidade dos parâmetros fixos.
 */
export function NumberInput({
  value,
  onChange,
  min = 0,
  max = 1_000_000,
  digits = 2,
  width = 110,
  ariaLabel,
  kind = 'decimal',
}: {
  value: number
  onChange: (v: number) => void
  min?: number
  max?: number
  digits?: number
  width?: number
  ariaLabel?: string
  kind?: NumberKind
}) {
  const unit = useApp((s) => s.settings.weightUnit)
  const maxFraction = kind === 'money' ? 2 : kind === 'weight' ? WEIGHT_UNITS[unit].digits : digits
  const plainInteger = kind === 'decimal' && digits === 0
  const display = (v: number) => {
    if (kind === 'money') return formatNumber(v, 2, 2)
    if (kind === 'weight') return formatNumber(fromGrams(v, unit), 0, maxFraction)
    const text = formatNumber(v, 0, digits)
    return plainInteger ? text.replace(/\./g, '') : text
  }
  const [text, setText] = useState(display(value))
  const [focused, setFocused] = useState(false)
  useEffect(() => {
    if (!focused) setText(display(value))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value, focused, digits, kind, unit])
  return (
    <input
      className="input number"
      inputMode="decimal"
      aria-label={ariaLabel}
      style={{ width }}
      value={text}
      onFocus={(e) => {
        setFocused(true)
        e.currentTarget.select()
      }}
      onBlur={() => {
        setFocused(false)
        setText(display(value))
      }}
      onKeyDown={(e) => e.key === 'Enter' && setText(display(value))}
      onChange={(e) => {
        let masked = liveMask(e.target.value, text, maxFraction)
        if (plainInteger) masked = masked.replace(/\./g, '')
        setText(masked)
        const typed = parseMasked(masked)
        if (!Number.isFinite(typed)) return
        const stored = kind === 'weight' ? toGrams(typed, unit) : typed
        onChange(Math.min(Math.max(stored, min), max))
      }}
    />
  )
}

export function NumberField({
  label,
  value,
  onChange,
  unit,
  hint,
  min,
  max,
  warn,
  kind,
}: {
  label: string
  value: number
  onChange: (v: number) => void
  unit?: string
  hint?: string
  min?: number
  max?: number
  warn?: boolean
  kind?: NumberKind
}) {
  const weightUnit = useApp((s) => s.settings.weightUnit)
  const currency = useApp((s) => s.settings.currency)
  const shownUnit = kind === 'weight' ? weightUnit : kind === 'money' ? currencySymbol(currency) + (unit ?? '') : unit
  return (
    <Row label={label} hint={hint && <span className={warn ? 'warn' : undefined}>{hint}</span>}>
      <NumberInput value={value} onChange={onChange} min={min} max={max} ariaLabel={label} kind={kind} />
      <span className="unit">{shownUnit}</span>
    </Row>
  )
}

export function TextField({
  label,
  value,
  onChange,
  placeholder,
  multiline,
  rows = 3,
  mask,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
  multiline?: boolean
  rows?: number
  /** Máscara aplicada a cada digitação (ex.: telefone, CPF/CNPJ). */
  mask?: (text: string) => string
}) {
  const id = useId()
  return (
    <div className="field">
      <label htmlFor={id}>{label}</label>
      {multiline ? (
        <textarea id={id} className="input" rows={rows} value={value} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} />
      ) : (
        <input id={id} className="input" value={value} placeholder={placeholder} onChange={(e) => onChange(mask ? mask(e.target.value) : e.target.value)} />
      )}
    </div>
  )
}

export function Stepper({
  value,
  onChange,
  min,
  max,
  label,
}: {
  value: number
  onChange: (v: number) => void
  min: number
  max: number
  label: string
}) {
  return (
    <span className="stepper" role="group" aria-label={label}>
      <button type="button" onClick={() => onChange(Math.max(min, value - 1))} disabled={value <= min} aria-label="Diminuir">
        −
      </button>
      <NumberInput value={value} onChange={(v) => onChange(Math.round(v))} min={min} max={max} digits={0} width={56} ariaLabel={label} />
      <button type="button" onClick={() => onChange(Math.min(max, value + 1))} disabled={value >= max} aria-label="Aumentar">
        +
      </button>
    </span>
  )
}

export function Modal({
  title,
  onClose,
  children,
  footer,
  wide,
}: {
  title: ReactNode
  onClose: () => void
  children: ReactNode
  footer?: ReactNode
  wide?: boolean
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  return (
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className={`modal ${wide ? 'wide' : ''}`} role="dialog" aria-modal>
        <header className="modal-header">{title}</header>
        <div className="modal-body">{children}</div>
        {footer && <footer className="modal-footer">{footer}</footer>}
      </div>
    </div>
  )
}

export function ConfirmDialog() {
  const confirm = useApp((s) => s.confirm)
  const close = useApp((s) => s.closeConfirm)
  if (!confirm) return null
  return (
    <Modal
      title={confirm.title}
      onClose={close}
      footer={
        <>
          <button className="btn" onClick={close}>
            Cancelar
          </button>
          <button
            className={`btn ${confirm.destructive ? 'danger' : 'primary'}`}
            autoFocus
            onClick={() => {
              close()
              confirm.onConfirm()
            }}
          >
            {confirm.confirmLabel}
          </button>
        </>
      }
    >
      <p>{confirm.message}</p>
    </Modal>
  )
}

export function Toast() {
  const toast = useApp((s) => s.toast)
  if (!toast) return null
  return (
    <div className={`toast ${toast.tone}`} role="status">
      {toast.message}
    </div>
  )
}

export function Empty({ icon: Icon, title, text, children }: { icon: LucideIcon; title: string; text?: string; children?: ReactNode }) {
  return (
    <div className="empty">
      <Icon size={40} strokeWidth={1.5} />
      <strong>{title}</strong>
      {text && <p>{text}</p>}
      {children}
    </div>
  )
}

export function PageHeader({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <header className="page-header">
      <h1>{title}</h1>
      <div className="page-actions">{children}</div>
    </header>
  )
}
