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
