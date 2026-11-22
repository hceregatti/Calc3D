import { Monitor, Moon, Sun } from 'lucide-react'
import { useState } from 'react'
import { Badge, ConfirmDialog, SCREEN_INFO, Toast } from './components/ui'
import { CompanyScreen, ShopSettingsScreen } from './screens/Settings'
import { FilamentsScreen } from './screens/Filaments'
import { HomeScreen } from './screens/Home'
import { PartsScreen } from './screens/Parts'
import { PrintJobScreen } from './screens/PrintJob'
import { ProposalsScreen } from './screens/Proposals'
import { loadTheme, saveTheme, useApp, type Screen, type ThemeMode } from './store'

const MAIN: Screen[] = ['home', 'printJob', 'parts', 'filaments', 'proposals']
const FOOTER: Screen[] = ['company', 'settings']

const THEMES: { mode: ThemeMode; label: string; icon: typeof Sun }[] = [
  { mode: 'system', label: 'Automático', icon: Monitor },
  { mode: 'light', label: 'Claro', icon: Sun },
  { mode: 'dark', label: 'Escuro', icon: Moon },
]

function ThemeToggle() {
  const [mode, setMode] = useState<ThemeMode>(loadTheme)
  return (
    <div className="theme-toggle" role="group" aria-label="Aparência">
      {THEMES.map(({ mode: m, label, icon: Icon }) => (
        <button key={m} type="button" className={mode === m ? 'active' : ''} title={label} aria-label={label} aria-pressed={mode === m}
          onClick={() => { setMode(m); saveTheme(m) }}>
          <Icon size={15} />
        </button>
      ))}
    </div>
  )
}

export function App() {
  const screen = useApp((s) => s.screen)
  const go = useApp((s) => s.go)

  const link = (id: Screen) => {
    const info = SCREEN_INFO[id]
    return (
      <button key={id} className={`nav-item ${screen === id ? 'active' : ''}`} onClick={() => go(id)} aria-current={screen === id ? 'page' : undefined}>
        <Badge icon={info.icon} color={info.color} size={28} />
        <span className="nav-text">
          <span>{info.title}</span>
          <small>{info.subtitle}</small>
        </span>
      </button>
    )
  }

  return (
    <div className="app">
      <nav className="sidebar">
        <div className="brand">
          <img src="./icon.png" alt="" width={28} height={28} />
          <strong>Calc3D</strong>
        </div>
        <div className="nav-main">{MAIN.map(link)}</div>
        <div className="nav-footer"><ThemeToggle />{FOOTER.map(link)}</div>
      </nav>
      <main className="content">
        {screen === 'home' && <HomeScreen />}
        {screen === 'printJob' && <PrintJobScreen />}
        {screen === 'parts' && <PartsScreen />}
        {screen === 'filaments' && <FilamentsScreen />}
        {screen === 'proposals' && <ProposalsScreen />}
        {screen === 'company' && <CompanyScreen />}
        {screen === 'settings' && <ShopSettingsScreen />}
      </main>
      <ConfirmDialog />
      <Toast />
    </div>
  )
}
