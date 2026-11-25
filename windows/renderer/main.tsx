import { Library } from 'lucide-react'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from '@web/App'
import { registerScreen } from '@web/extensions'
import { applyTheme, loadTheme, useApp } from '@web/store'
import '@web/styles.css'
import '@web/design-system.css'
import './macos.css'
import { CatalogScreen } from './catalog/CatalogScreen'
import { DesktopShell } from './Shell'
import { Titlebar } from './Titlebar'

// Tela que só existe no app desktop: o catálogo lê uma pasta do computador.
registerScreen({
  id: 'catalog',
  title: 'Catálogo',
  subtitle: 'Modelos 3MF/STL compartilhados',
  icon: Library,
  color: '#30b0c7',
  component: CatalogScreen,
  after: 'filaments',
})

// O store lê o endereço (#/catalog) antes da tela ser registrada.
const initial = location.hash.replace('#/', '')
if (initial === 'catalog') useApp.setState({ screen: 'catalog' })

document.documentElement.dataset.platform = window.calc3d?.platform ?? 'win32'
applyTheme(loadTheme())
navigator.storage?.persist?.().catch(() => {})
useApp.getState().cleanupImages()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Titlebar />
    <App />
    <DesktopShell />
  </StrictMode>,
)
