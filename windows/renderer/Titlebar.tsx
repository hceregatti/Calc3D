import { PanelLeft } from 'lucide-react'
import { useEffect, useState } from 'react'
import { SCREEN_INFO } from '@web/components/ui'
import { extraScreens } from '@web/extensions'
import { useApp, type BuiltinScreen } from '@web/store'
import { bridge } from './bridge'

const SIDEBAR_KEY = 'calc3d.desktop.sidebarHidden'

/** A janela efetivamente escura (tema escolhido no app ou, no automático, o do sistema). */
const isDark = () => {
  const forced = document.documentElement.getAttribute('data-theme')
  return forced ? forced === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches
}

/** Barra de título própria: botão da barra lateral e nome da tela, como a barra de ferramentas do macOS. */
export function Titlebar() {
  const screen = useApp((s) => s.screen)
  const title = (extraScreens.find((e) => e.id === screen) ?? SCREEN_INFO[screen as BuiltinScreen])?.title ?? 'Calc3D'
  const [hidden, setHidden] = useState(() => localStorage.getItem(SIDEBAR_KEY) === '1')

  useEffect(() => {
    document.documentElement.dataset.sidebar = hidden ? 'hidden' : 'shown'
    localStorage.setItem(SIDEBAR_KEY, hidden ? '1' : '0')
  }, [hidden])

  // Mantém os botões da janela (minimizar/maximizar/fechar) legíveis no claro e no escuro.
  useEffect(() => {
    const sync = () => void bridge().setWindowTheme(isDark())
    sync()
    const observer = new MutationObserver(sync)
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] })
    const media = matchMedia('(prefers-color-scheme: dark)')
    media.addEventListener('change', sync)
    return () => { observer.disconnect(); media.removeEventListener('change', sync) }
  }, [])

  useEffect(() => { document.title = `${title} — Calc3D` }, [title])

  return (
    <header className="titlebar">
      <div className="titlebar-left">
        <button type="button" title="Mostrar ou ocultar a barra lateral" aria-label="Barra lateral" onClick={() => setHidden(!hidden)}>
          <PanelLeft size={18} />
        </button>
      </div>
      <h1 className="titlebar-title">{title}</h1>
    </header>
  )
}
