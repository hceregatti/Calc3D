import { Box, ChevronRight, DollarSign, FilePlus2, FileText, PencilRuler, type LucideIcon } from 'lucide-react'
import { useMemo, type ReactNode } from 'react'
import { brl, calculate } from '../core/calculator'
import { displayName, fromCents, totalCents } from '../core/models'
import { Badge, SCREEN_INFO } from '../components/ui'
import { useApp } from '../store'

export function HomeScreen() {
  const { quotes, proposals, job, settings, newJob, startNewProposal, go, openProposal, setSelectedQuoteIds } = useApp()
  const result = useMemo(() => calculate(settings, job), [settings, job])
  const proposalsTotal = proposals.reduce((sum, p) => sum + fromCents(totalCents(p)), 0)

  return (
    <div className="page home">
      <header className="home-header">
        <img src="./icon.png" alt="" width={64} height={64} />
        <div>
          <h1>Calc3D</h1>
          <p>Calcule peças, guarde no histórico e monte orçamentos com várias peças.</p>
        </div>
      </header>

      <div className="action-grid">
        <ActionCard prominent title="Calcular peça" subtitle="Novo cálculo a partir do fatiador" icon={Box} color={SCREEN_INFO.printJob.color} onClick={newJob} />
        <ActionCard title="Novo orçamento" subtitle="Junte várias peças do histórico" icon={FilePlus2} color={SCREEN_INFO.proposals.color} onClick={startNewProposal} />
        <ActionCard title="Peças" subtitle="Histórico de cálculos salvos" icon={SCREEN_INFO.parts.icon} color={SCREEN_INFO.parts.color} onClick={() => go('parts')} />
        <ActionCard title="Parâmetros" subtitle="Filamento, máquina e taxas" icon={SCREEN_INFO.settings.icon} color={SCREEN_INFO.settings.color} onClick={() => go('settings')} />
      </div>

      <div className="stat-grid">
        <Stat value={String(quotes.length)} title="Peças no histórico" icon={SCREEN_INFO.parts.icon} color={SCREEN_INFO.parts.color} />
        <Stat value={String(proposals.length)} title="Orçamentos" icon={FileText} color={SCREEN_INFO.proposals.color} />
        <Stat value={brl(proposalsTotal)} title="Valor total em orçamentos" icon={DollarSign} color="#30b0c7" />
        <Stat
          value={result.suggestedPrice === null ? '—' : brl(result.suggestedPrice)}
          title={job.name ? `Em andamento: ${job.name}` : 'Cálculo em andamento'}
          icon={PencilRuler}
          color={SCREEN_INFO.printJob.color}
        />
      </div>

      <div className="recent-grid">
        <Recent title="Peças recentes" empty="Nenhuma peça salva ainda." isEmpty={!quotes.length} onAll={() => go('parts')}>
          {quotes.slice(0, 5).map((q) => (
            <RecentRow
              key={q.id}
              title={displayName(q.job.name, 'Peça sem nome')}
              detail={new Date(q.savedAt).toLocaleString('pt-BR', { dateStyle: 'medium', timeStyle: 'short' })}
              value={q.result.suggestedPrice === null ? '—' : brl(q.result.suggestedPrice)}
              icon={Box}
              color={SCREEN_INFO.parts.color}
              onClick={() => {
                setSelectedQuoteIds([q.id])
                go('parts')
              }}
            />
          ))}
        </Recent>
        <Recent title="Orçamentos recentes" empty="Nenhum orçamento criado ainda." isEmpty={!proposals.length} onAll={() => go('proposals')}>
          {proposals.slice(0, 5).map((p) => (
            <RecentRow
              key={p.id}
              title={displayName(p.title, 'Orçamento sem título')}
              detail={`${p.items.length} ${p.items.length === 1 ? 'item' : 'itens'}${p.customerName ? ` · ${p.customerName}` : ''}`}
              value={brl(fromCents(totalCents(p)))}
              icon={FileText}
              color={SCREEN_INFO.proposals.color}
              onClick={() => openProposal(p.id)}
            />
          ))}
        </Recent>
      </div>
    </div>
  )
}

function ActionCard(props: { title: string; subtitle: string; icon: LucideIcon; color: string; prominent?: boolean; onClick: () => void }) {
  const Icon = props.icon
  return (
    <button
      className={`action-card ${props.prominent ? 'prominent' : ''}`}
      style={props.prominent ? { background: `linear-gradient(160deg, color-mix(in srgb, ${props.color} 85%, white), ${props.color})` } : undefined}
      onClick={props.onClick}
    >
      {props.prominent ? (
        <span className="action-icon"><Icon size={24} strokeWidth={2.4} /></span>
      ) : (
        <Badge icon={props.icon} color={props.color} size={36} />
      )}
      <span className="grow" />
      <strong>{props.title}</strong>
      <small>{props.subtitle}</small>
    </button>
  )
}

function Stat({ value, title, icon, color }: { value: string; title: string; icon: LucideIcon; color: string }) {
  return (
    <div className="stat">
      <Badge icon={icon} color={color} size={24} />
      <strong className="num">{value}</strong>
      <small>{title}</small>
    </div>
  )
}

function Recent({ title, empty, isEmpty, onAll, children }: { title: string; empty: string; isEmpty: boolean; onAll: () => void; children: ReactNode }) {
  return (
    <div className="card recent">
      <div className="recent-header">
        <h3>{title}</h3>
        <button className="link" disabled={isEmpty} onClick={onAll}>Ver todos</button>
      </div>
      {isEmpty ? <p className="muted center pad">{empty}</p> : <div>{children}</div>}
    </div>
  )
}

function RecentRow(props: { title: string; detail: string; value: string; icon: LucideIcon; color: string; onClick: () => void }) {
  return (
    <button className="recent-row" onClick={props.onClick}>
      <Badge icon={props.icon} color={props.color} size={26} />
      <span className="grow text">
        <span className="ellipsis">{props.title}</span>
        <small className="muted ellipsis">{props.detail}</small>
      </span>
      <span className="num muted">{props.value}</span>
      <ChevronRight size={14} className="muted" />
    </button>
  )
}
