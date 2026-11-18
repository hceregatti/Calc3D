import { describe, expect, it } from 'vitest'
import { calculate, defaultJob, defaultSettings } from './calculator'
import { filamentDisplayName, filamentPricePerGram, newFilament, purchaseLink, searchUrl } from './filament'

describe('biblioteca de filamentos', () => {
  it('calcula preço por grama, nome e busca', () => {
    const f = { ...newFilament('PETG'), brand: 'Voolt3D', name: 'Basic', colorName: 'Preto', price: 90 }
    expect(filamentPricePerGram(f)).toBe(0.09)
    expect(f.nozzleTempMin).toBe(220)
    expect(filamentDisplayName(f)).toBe('Voolt3D Basic PETG · Preto')
    expect(searchUrl(f)).toContain('tbm=shop')
    expect(searchUrl(f)).toContain('Voolt3D')
  })

  it('aceita só links http/https', () => {
    const f = newFilament()
    expect(purchaseLink({ ...f, purchaseUrl: 'loja.com.br/produto' })).toBe('https://loja.com.br/produto')
    expect(purchaseLink({ ...f, purchaseUrl: 'javascript:alert(1)' })).toBeNull()
    expect(purchaseLink({ ...f, purchaseUrl: '' })).toBeNull()
  })

  it('o filamento da peça substitui o rolo padrão no custo', () => {
    const base = calculate(defaultSettings, defaultJob).items.find((i) => i.category === 'filament')!.amount
    const perGram = defaultSettings.spoolPrice / defaultSettings.spoolWeight
    const doubled = calculate(defaultSettings, { ...defaultJob, filamentPricePerGram: perGram * 2 }).items.find((i) => i.category === 'filament')!.amount
    expect(doubled).toBeCloseTo(base * 2, 9)
  })
})

import { deduct, gramsPerUnit, isRunningLow, requirements, revert, shortage, usageChanged } from './filament'

describe('consumo e baixa de estoque', () => {
  it('gramas por unidade com desperdício e peças por mesa', () => {
    expect(gramsPerUnit(defaultJob)).toBeNull()
    expect(gramsPerUnit({ ...defaultJob, filamentId: 'a', partWeight: 200, wastePercent: 10, partsPerPlate: 2 })).toBeCloseTo(110, 9)
  })

  it('soma por rolo, ignorando itens sem filamento', () => {
    const reqs = requirements([
      { filamentId: 'a', filamentName: 'A', gramsPerUnit: 50, quantity: 3 },
      { filamentId: 'a', filamentName: 'A', gramsPerUnit: 10, quantity: 1 },
      { filamentId: 'b', filamentName: 'B', gramsPerUnit: 5, quantity: 2 },
      { filamentId: null, filamentName: '', gramsPerUnit: null, quantity: 9 },
    ])
    expect(reqs.map((r) => r.grams)).toEqual([160, 10])
  })

  it('baixa limitada a zero, estorno exato e detecção de edição', () => {
    const f = { ...newFilament(), remainingWeight: 100 }
    const need = [{ filamentId: f.id, filamentName: 'X', grams: 150 }]
    const { filaments, deductions } = deduct(need, [f])
    expect(filaments[0].remainingWeight).toBe(0)
    expect(deductions[0]).toMatchObject({ grams: 100, requestedGrams: 150 })
    expect(revert(deductions, filaments)[0].remainingWeight).toBe(100)
    expect(usageChanged(deductions, need)).toBe(false)
    expect(usageChanged(deductions, [{ ...need[0], grams: 120 }])).toBe(true)
  })

  it('falta e acabando', () => {
    expect(shortage(300, 180)).toBe(120)
    expect(shortage(100, 180)).toBe(0)
    expect(isRunningLow({ ...newFilament(), remainingWeight: 100 })).toBe(true)
    expect(isRunningLow({ ...newFilament(), remainingWeight: 400 })).toBe(false)
  })
})
