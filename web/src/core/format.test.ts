import { describe, expect, it } from 'vitest'
import { cpfCnpjMask, formatNumber, liveMask, money, parseMasked, phoneMask, toGrams, weight, withValidDisplay } from './format'

// Mesmos casos de Tests/Calc3DCoreTests/FormattingTests.swift.
describe('máscara numérica', () => {
  it('formata no padrão brasileiro', () => {
    expect(formatNumber(31.17)).toBe('31,17')
    expect(formatNumber(7000, 2, 2)).toBe('7.000,00')
  })

  it('lê texto mascarado', () => {
    expect(parseMasked('7.000,00')).toBe(7000)
    expect(parseMasked('31,17')).toBe(31.17)
    expect(parseMasked(',5')).toBe(0.5)
    expect(parseMasked('')).toBeNaN()
  })

  it('aplica a máscara ao digitar', () => {
    expect(liveMask('7000')).toBe('7.000')
    expect(liveMask('1.0000', '1.000')).toBe('10.000')
    expect(liveMask('31.', '31')).toBe('31,')
    expect(liveMask('31.17')).toBe('31,17')
    expect(liveMask('7.00', '7.000')).toBe('700')
    expect(liveMask('7.000')).toBe('7.000')
    expect(liveMask('1,239')).toBe('1,23')
    expect(liveMask('0,7509', '', 3)).toBe('0,750')
    expect(liveMask(',5')).toBe('0,5')
    expect(liveMask('007')).toBe('7')
  })
})

describe('moeda e peso', () => {
  it('formata a moeda escolhida', () => {
    expect(money(7000, 'BRL').replace(/\s/g, ' ')).toBe('R$ 7.000,00')
    expect(money(7000, 'USD')).toContain('7.000,00')
  })

  it('converte peso', () => {
    expect(weight(31.17, 'g')).toBe('31,17 g')
    expect(weight(1500, 'kg')).toBe('1,5 kg')
    expect(toGrams(1, 'lb')).toBeCloseTo(453.59237)
  })

  it('corrige preferências inválidas', () => {
    const s = withValidDisplay({ currency: 'XYZ', weightUnit: 'ton' } as never)
    expect(s).toMatchObject({ currency: 'BRL', weightUnit: 'g' })
  })
})

describe('documentos', () => {
  it('telefone', () => {
    expect(phoneMask('11')).toBe('(11')
    expect(phoneMask('113')).toBe('(11) 3')
    expect(phoneMask('1130000000')).toBe('(11) 3000-0000')
    expect(phoneMask('11900000000')).toBe('(11) 90000-0000')
    expect(phoneMask('contato@x.com')).toBe('contato@x.com')
  })

  it('CPF e CNPJ', () => {
    expect(cpfCnpjMask('12345678901')).toBe('123.456.789-01')
    expect(cpfCnpjMask('12345678000195')).toBe('12.345.678/0001-95')
    expect(cpfCnpjMask('12abc34501de35')).toBe('12.ABC.345/01DE-35')
  })
})
