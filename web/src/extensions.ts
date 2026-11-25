import type { LucideIcon } from 'lucide-react'
import type { ComponentType } from 'react'

/**
 * Ponto de extensão: um app que embute a versão web (ex.: o app Windows, em `windows/`) registra aqui
 * telas extras antes de montar o <App />. Na web pura a lista fica vazia.
 */
export interface ExtraScreen {
  id: string
  title: string
  subtitle: string
  icon: LucideIcon
  color: string
  component: ComponentType
  /** Tela da barra lateral depois da qual esta aparece. */
  after: string
}

export const extraScreens: ExtraScreen[] = []

export function registerScreen(screen: ExtraScreen) {
  extraScreens.push(screen)
}
