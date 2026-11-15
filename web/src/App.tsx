import { Badge, ConfirmDialog, SCREEN_INFO, Toast } from './components/ui'
import { CompanyScreen, ShopSettingsScreen } from './screens/Settings'
import { HomeScreen } from './screens/Home'
import { PartsScreen } from './screens/Parts'
import { PrintJobScreen } from './screens/PrintJob'
import { ProposalsScreen } from './screens/Proposals'
import { useApp, type Screen } from './store'

const MAIN: Screen[] = ['home', 'printJob', 'parts', 'proposals']
const FOOTER: Screen[] = ['company', 'settings']

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
        <div className="nav-footer">{FOOTER.map(link)}</div>
      </nav>
      <main className="content">
        {screen === 'home' && <HomeScreen />}
        {screen === 'printJob' && <PrintJobScreen />}
        {screen === 'parts' && <PartsScreen />}
        {screen === 'proposals' && <ProposalsScreen />}
        {screen === 'company' && <CompanyScreen />}
        {screen === 'settings' && <ShopSettingsScreen />}
      </main>
      <ConfirmDialog />
      <Toast />
    </div>
  )
}
