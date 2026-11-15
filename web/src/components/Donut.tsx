import { CATEGORIES, brl, unitCost, type CostResult } from '../core/calculator'

/** Rosca com a composição do custo por peça. */
export function Donut({ result, size = 170 }: { result: CostResult; size?: number }) {
  const total = unitCost(result)
  const radius = size / 2 - 12
  const circumference = 2 * Math.PI * radius
  const gap = total > 0 ? 2 : 0
  let offset = 0
  const segments = result.items
    .filter((i) => i.amount > 0 && total > 0)
    .map((item) => {
      const length = (item.amount / total) * circumference
      const color = CATEGORIES.find((c) => c.id === item.category)!.color
      const segment = (
        <circle
          key={item.category}
          r={radius}
          cx={size / 2}
          cy={size / 2}
          fill="none"
          stroke={color}
          strokeWidth={20}
          strokeDasharray={`${Math.max(length - gap, 0.5)} ${circumference}`}
          strokeDashoffset={-offset}
        >
          <title>{`${CATEGORIES.find((c) => c.id === item.category)!.title}: ${brl(item.amount)}`}</title>
        </circle>
      )
      offset += length
      return segment
    })
  return (
    <div className="donut" style={{ width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }} role="img" aria-label="Composição do custo">
        <circle r={radius} cx={size / 2} cy={size / 2} fill="none" stroke="var(--fill)" strokeWidth={20} />
        {segments}
      </svg>
      <div className="donut-center">
        <strong>{brl(total)}</strong>
        <small>por peça</small>
      </div>
    </div>
  )
}
