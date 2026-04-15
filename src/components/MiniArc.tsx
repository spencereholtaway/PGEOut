import { arcFillPct } from '../utils/time'

interface Props {
  startMs: number | null
  etaMs: number | null
}

const SIZE   = 52
const STROKE = 6
const R      = (SIZE - STROKE) / 2
const CX     = SIZE / 2
const CY     = SIZE / 2

const CIRCUMFERENCE = 2 * Math.PI * R
const ARC_DEG       = 240
const ARC_LENGTH    = CIRCUMFERENCE * (ARC_DEG / 360)
const GAP_LENGTH    = CIRCUMFERENCE - ARC_LENGTH

const START_ANGLE_DEG = 150
const ROTATE = `rotate(${START_ANGLE_DEG}, ${CX}, ${CY})`

const trackDash = `${ARC_LENGTH} ${GAP_LENGTH}`

export default function MiniArc({ startMs, etaMs }: Props) {
  const pct     = (startMs && etaMs) ? arcFillPct(startMs, etaMs) : 0
  const fillLen = (pct / 100) * ARC_LENGTH
  const fillDash = `${fillLen} ${CIRCUMFERENCE - fillLen}`

  return (
    <svg width={SIZE} height={SIZE} viewBox={`0 0 ${SIZE} ${SIZE}`} style={{ flexShrink: 0 }}>
      {/* Track */}
      <circle
        cx={CX} cy={CY} r={R}
        fill="none" stroke="#E5E7EB" strokeWidth={STROKE}
        strokeLinecap="round" strokeDasharray={trackDash}
        transform={ROTATE}
      />
      {/* Fill */}
      <circle
        cx={CX} cy={CY} r={R}
        fill="none" stroke="#F97316" strokeWidth={STROKE}
        strokeLinecap="round" strokeDasharray={fillDash}
        transform={ROTATE}
      />
    </svg>
  )
}
