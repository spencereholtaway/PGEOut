import { useEffect, useState } from 'react'
import { arcFillPct } from '../utils/time'

interface Props {
  startMs: number | null
  etaMs: number | null
  triggerAnimation?: boolean
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

export default function MiniArc({ startMs, etaMs, triggerAnimation }: Props) {
  const [animated, setAnimated] = useState(false)

  useEffect(() => {
    // If triggerAnimation is controlled externally, use it; otherwise self-trigger after 50ms
    if (triggerAnimation === undefined) {
      const id = setTimeout(() => setAnimated(true), 50)
      return () => clearTimeout(id)
    }
  }, [])

  useEffect(() => {
    if (triggerAnimation) setAnimated(true)
  }, [triggerAnimation])

  const pct        = (startMs && etaMs) ? arcFillPct(startMs, etaMs) : 0
  const fillLen    = animated ? (pct / 100) * ARC_LENGTH : 0
  const fillDash   = `${ARC_LENGTH} ${GAP_LENGTH}`
  const fillOffset = ARC_LENGTH - fillLen
  const arcColor   = pct >= 67 ? '#219653' : pct >= 34 ? '#F2994A' : '#EB5757'

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
        fill="none" stroke={arcColor} strokeWidth={STROKE}
        strokeLinecap="round" strokeDasharray={fillDash} strokeDashoffset={fillOffset}
        transform={ROTATE}
        style={{ transition: 'stroke-dashoffset 1s ease-out' }}
      />
    </svg>
  )
}
