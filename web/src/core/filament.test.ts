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
