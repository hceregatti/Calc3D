import { useEffect, useState } from 'react'
import { Modal } from '@web/components/ui'
import { calculate, quoteSummary } from '@web/core/calculator'
import { useApp } from '@web/store'
import { bridge, type ReleaseInfo } from './bridge'

type Phase =
  | { kind: 'idle' }
  | { kind: 'checking' }
  | { kind: 'upToDate' }
  | { kind: 'available'; release: ReleaseInfo }
  | { kind: 'installing'; release: ReleaseInfo }
  | { kind: 'failed'; message: string }

const SKIPPED = 'calc3d.desktop.skippedVersion'

/** Liga o menu nativo e a janela de atualização ao app web. Não desenha nada além da janela de atualização. */
export function DesktopShell() {
  const [phase, setPhase] = useState<Phase>({ kind: 'idle' })

  const check = async (manual: boolean) => {
    if (manual) setPhase({ kind: 'checking' })
    const result = await bridge().updates.check()
    if (result.status === 'error') {
      // Falhas na checagem automática são silenciosas (ex.: sem internet).
      if (manual) setPhase({ kind: 'failed', message: 'Não foi possível buscar atualizações. Verifique sua conexão e tente novamente.' })
      return
    }
    if (result.status === 'upToDate') return setPhase(manual ? { kind: 'upToDate' } : { kind: 'idle' })
    if (!manual && localStorage.getItem(SKIPPED) === result.release.version) return
    setPhase({ kind: 'available', release: result.release })
  }

  useEffect(() => {
    void check(false)
    return bridge().onMenu((action) => {
      const app = useApp.getState()
      if (action.startsWith('go:')) app.go(action.slice(3))
      else if (action === 'newJob') app.newJob()
      else if (action === 'newProposal') app.startNewProposal()
      else if (action === 'checkUpdates') void check(true)
      else if (action === 'copySummary') {
        const { settings, job } = app
        navigator.clipboard.writeText(quoteSummary(calculate(settings, job), job)).then(
          () => app.showToast('Resumo copiado ✔'),
          () => app.showToast('Não foi possível copiar.', 'error'),
        )
      }
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const close = () => setPhase({ kind: 'idle' })
  if (phase.kind === 'idle') return null

  const install = async (release: ReleaseInfo) => {
    setPhase({ kind: 'installing', release })
    try {
      const { manual } = await bridge().updates.install(release)
      if (manual) close()
    } catch {
      setPhase({ kind: 'failed', message: 'A atualização falhou. Você pode baixar a versão manualmente na página de releases.' })
    }
  }

  return (
    <Modal
      title={phase.kind === 'available' || phase.kind === 'installing' ? `Calc3D ${phase.release.version} disponível` : 'Atualizações'}
      onClose={phase.kind === 'installing' ? () => {} : close}
      footer={
        phase.kind === 'available' ? (
          <>
            <button className="btn" onClick={() => { localStorage.setItem(SKIPPED, phase.release.version); close() }}>Pular esta versão</button>
            <button className="btn" onClick={close}>Mais tarde</button>
            <button className="btn primary" autoFocus onClick={() => void install(phase.release)}>Atualizar agora</button>
          </>
        ) : phase.kind === 'installing' ? null : (
          <>
            {phase.kind === 'failed' && <button className="btn" onClick={() => void bridge().updates.openPage('https://github.com/hceregatti/Calc3D/releases/latest')}>Abrir página de releases</button>}
            <button className="btn primary" onClick={close}>OK</button>
          </>
        )
      }
    >
      {phase.kind === 'checking' && <p>Buscando atualizações…</p>}
      {phase.kind === 'upToDate' && <p>Você já está com a versão mais recente do Calc3D.</p>}
      {phase.kind === 'failed' && <p className="warn">{phase.message}</p>}
      {phase.kind === 'installing' && <p>Baixando a atualização… O Calc3D vai fechar e o instalador abrirá em seguida.</p>}
      {phase.kind === 'available' && (
        <>
          <p>Você usa a versão atual; a versão {phase.release.version} já pode ser instalada.</p>
          {phase.release.notes.length > 0 && (
            <ul style={{ margin: '8px 0 0', paddingLeft: 18 }}>{phase.release.notes.map((n, i) => <li key={i}>{n}</li>)}</ul>
          )}
        </>
      )}
    </Modal>
  )
}
