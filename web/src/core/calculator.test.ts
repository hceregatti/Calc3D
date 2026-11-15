import { describe, expect, it } from 'vitest'
import {
  amountFor,
  calculate,
  defaultJob,
  defaultSettings,
  derived,
  plateCost,
  profitPerMachineHour,
  profitPerPart,
  quoteSummary,
  unitCost,
  type PrintJob,
  type ShopSettings,
} from './calculator'

// Mesmos casos de Tests/Calc3DCoreTests/CostCalculatorTests.swift.
const approx = (a: number, b: number, tol = 0.005) => expect(Math.abs(a - b)).toBeLessThanOrEqual(tol)
const calc = (s: Partial<ShopSettings> = {}, j: Partial<PrintJob> = {}) =>
  calculate({ ...defaultSettings, ...s }, { ...defaultJob, ...j })

describe('calculate', () => {
  it('valores padrão produzem os custos esperados', () => {
    const r = calc()
    approx(amountFor(r, 'filament'), 10.71)
    approx(amountFor(r, 'energy'), 1.02375)
    approx(amountFor(r, 'depreciation'), 3.64)
    approx(amountFor(r, 'maintenance'), 1.7333)
    approx(amountFor(r, 'overhead'), 7.8)
    approx(amountFor(r, 'labor'), 17.5)
    approx(amountFor(r, 'supplies'), 5)
    const production = 10.71 + 1.02375 + 3.64 + 1.73333 + 7.8
    approx(amountFor(r, 'failures'), (production * 0.1) / 0.9)
    approx(r.suggestedPrice!, (unitCost(r) + 4) / 0.4)
  })

  it('custos por hora derivados dos parâmetros fixos', () => {
    const d = derived(defaultSettings)
    approx(d.filamentPricePerGram, 0.12)
    approx(d.energyCostPerHour, 0.1575)
    approx(d.depreciationPerHour, 0.56)
    approx(d.maintenancePerHour, 0.2667)
    approx(d.overheadPerHour, 1.2)
    approx(d.machineCostPerHour, 0.1575 + 0.56 + 0.26667 + 1.2)
  })

  it('taxa de falha usa divisão por (1 − f)', () => {
    const r = calc({ failureRatePercent: 20 })
    const production =
      amountFor(r, 'filament') + amountFor(r, 'energy') + amountFor(r, 'depreciation') +
      amountFor(r, 'maintenance') + amountFor(r, 'overhead')
    approx(production + amountFor(r, 'failures'), production / 0.8)
  })

  it('custo é dividido pelas peças da mesa; embalagem é por peça', () => {
    const one = calc()
    const four = calc({}, { partsPerPlate: 4 })
    approx(amountFor(four, 'filament'), amountFor(one, 'filament') / 4)
    approx(amountFor(four, 'supplies'), (2 + 3 * 4) / 4)
    approx(plateCost(four), unitCost(four) * 4)
  })

  it('percentuais >= 100% retornam erro de precificação', () => {
    const r = calc({ taxPercent: 10, marketplaceFeePercent: 10 }, { marginPercent: 80 })
    expect(r.suggestedPrice).toBeNull()
    expect(profitPerPart(r)).toBeNull()
  })

  it('entradas inválidas não geram NaN nem valores negativos', () => {
    const r = calc(
      { spoolWeight: 0, lifetimeHours: 0, resaleValue: 99_999, failureRatePercent: 100 },
      { partsPerPlate: 0, partWeight: -Infinity, printMinutes: -30 },
    )
    expect(r.items.every((i) => Number.isFinite(i.amount) && i.amount >= 0)).toBe(true)
    expect(r.partsPerPlate).toBe(1)
    expect(amountFor(r, 'depreciation')).toBe(0)
    expect(r.printHours).toBe(6)
  })

  it('lucro por hora considera todas as peças da mesa', () => {
    const r = calc({}, { partsPerPlate: 2 })
    approx(profitPerMachineHour(r)!, (profitPerPart(r)! * 2) / 6.5)
  })

  it('resumo usa o nome da peça e o preço em reais', () => {
    const job = { ...defaultJob, name: 'Suporte de headset' }
    const text = quoteSummary(calculate(defaultSettings, job), job)
    expect(text.startsWith('Orçamento: Suporte de headset')).toBe(true)
    expect(text).toMatch(/Preço sugerido: R\$/)
    expect(quoteSummary(calc(), defaultJob).startsWith('Orçamento impressão 3D')).toBe(true)
  })
})
