import { describe, expect, it } from 'vitest'
import {
  defaultCompany,
  formattedNumber,
  itemsTotalCents,
  newItem,
  newProposal,
  toCents,
  totalCents,
  validUntil,
  withDefaults,
} from './models'

describe('orçamento', () => {
  it('soma itens em centavos, com frete e desconto', () => {
    const p = newProposal(defaultCompany)
    p.items = [newItem({ name: 'A', unitPrice: 45.9, quantity: 2 }), newItem({ name: 'B', unitPrice: 0.1, quantity: 3 })]
    expect(itemsTotalCents(p)).toBe(9210)
    p.shippingCents = toCents(25)
    p.discountCents = toCents(10)
    expect(totalCents(p)).toBe(9210 + 2500 - 1000)
  })

  it('desconto maior que o total não gera valor negativo', () => {
    const p = newProposal(defaultCompany)
    p.items = [newItem({ name: 'A', unitPrice: 10 })]
    p.discountCents = toCents(50)
    expect(totalCents(p)).toBe(0)
  })

  it('valores inválidos viram zero e quantidade fica entre 1 e 9999', () => {
    expect(toCents(-5)).toBe(0)
    expect(toCents(NaN)).toBe(0)
    expect(newItem({ name: 'A', unitPrice: 1, quantity: 0 }).quantity).toBe(1)
    expect(newItem({ name: 'A', unitPrice: 1, quantity: 1e9 }).quantity).toBe(9999)
  })

  it('usa os padrões da empresa, número com 4 dígitos e validade em dias', () => {
    const p = newProposal({ ...defaultCompany, defaultValidityDays: 10 })
    expect(p.paymentTerms).toBe(defaultCompany.defaultPaymentTerms)
    expect(formattedNumber(p)).toBeNull()
    p.number = 42
    expect(formattedNumber(p)).toBe('0042')
    p.updatedAt = new Date(2026, 10, 15).toISOString()
    expect(validUntil(p)?.getDate()).toBe(25)
    p.validityDays = 0
    expect(validUntil(p)).toBeNull()
  })

  it('dados salvos antigos recebem os campos novos com valores padrão', () => {
    const merged = withDefaults(defaultCompany, { companyName: 'X', footerText: 3 })
    expect(merged.companyName).toBe('X')
    expect(merged.footerText).toBe(defaultCompany.footerText)
    expect(merged.nextProposalNumber).toBe(1)
  })
})

import { daysUntilExpiry, proposalStatus, proposalsIn } from './models'

describe('situação do orçamento', () => {
  const at = (iso: string, validityDays: number, sold = false): ReturnType<typeof newProposal> => ({
    ...newProposal(defaultCompany),
    updatedAt: iso,
    validityDays,
    saleConfirmedAt: sold ? iso : null,
  })
  const day = (d: number, h = 12) => new Date(2026, 10, d, h)

  it('aguarda até o último dia de validade e vence no dia seguinte', () => {
    const p = at(day(1).toISOString(), 15)
    expect(proposalStatus(p, day(10))).toBe('waiting')
    expect(proposalStatus(p, day(16, 23))).toBe('waiting')
    expect(daysUntilExpiry(p, day(16))).toBe(0)
    expect(proposalStatus(p, day(17, 0))).toBe('expired')
    expect(daysUntilExpiry(p, day(19))).toBe(-3)
  })

  it('sem validade nunca vence; venda confirmada vence qualquer prazo', () => {
    expect(proposalStatus(at(day(1).toISOString(), 0), day(30))).toBe('waiting')
    expect(proposalStatus(at(day(1).toISOString(), 5, true), day(30))).toBe('sold')
  })

  it('ordena a fila pelos que vencem primeiro', () => {
    const a = { ...at(day(1).toISOString(), 30), title: 'A' }
    const b = { ...at(day(1).toISOString(), 10), title: 'B' }
    const c = { ...at(day(1).toISOString(), 0), title: 'C' }
    expect(proposalsIn([a, c, b], 'waiting', day(5)).map((p) => p.title)).toEqual(['B', 'A', 'C'])
  })
})
