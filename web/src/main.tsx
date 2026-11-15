import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from './App'
import { useApp } from './store'
import './styles.css'
import './design-system.css'

// Pede ao navegador para não apagar os dados locais sob pressão de espaço.
navigator.storage?.persist?.().catch(() => {})
useApp.getState().cleanupImages()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
