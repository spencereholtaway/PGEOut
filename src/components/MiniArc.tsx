import { useEffect, useState } from 'react'
import { arcFillPct } from '../utils/time'

interface Props {
  startMs:          number | null
  etaMs:            number | null
  isPlanned?:       boolean
  triggerAnimation?: boolean
}

const SIZE   = 36
const STROKE = 5
const R      = (SIZE - STROKE) / 2
const CX     = SIZE / 2
const CY     = SIZE / 2

const CIRCUMFERENCE   = 2 * Math.PI * R
const ARC_DEG         = 240
const ARC_LENGTH      = CIRCUMFERENCE * (ARC_DEG / 360)
const GAP_LENGTH      = CIRCUMFERENCE - ARC_LENGTH
const START_ANGLE_DEG = 150
const ROTATE          = `rotate(${START_ANGLE_DEG}, ${CX}, ${CY})`
const trackDash       = `${ARC_LENGTH} ${GAP_LENGTH}`

export default function MiniArc({ startMs, etaMs, isPlanned, triggerAnimation }: Props) {
  const [animated, setAnimated] = useState(false)

  useEffect(() => {
    if (triggerAnimation === undefined) {
      const id = setTimeout(() => setAnimated(true), 50)
      return () => clearTimeout(id)
    }
  }, [])

  useEffect(() => {
    if (triggerAnimation) setAnimated(true)
  }, [triggerAnimation])

  const pct      = (startMs && etaMs) ? arcFillPct(startMs, etaMs) : 0
  const fillLen  = animated ? (pct / 100) * ARC_LENGTH : 0
  const fillDash = `${fillLen} ${CIRCUMFERENCE - fillLen}`
  const color    = isPlanned ? '#70A489' : '#FFA100'

  return (
    <svg width={SIZE} height={SIZE} viewBox={`0 0 ${SIZE} ${SIZE}`} style={{ flexShrink: 0 }}>
      <circle cx={CX} cy={CY} r={R}
        fill="none" strokeWidth={STROKE}
        strokeLinecap="round" strokeDasharray={trackDash}
        transform={ROTATE}
        style={{ stroke: 'var(--arc-track)' }}
      />
      <circle cx={CX} cy={CY} r={R}
        fill="none" stroke={color} strokeWidth={STROKE}
        strokeLinecap="round" strokeDasharray={fillDash}
        transform={ROTATE}
        style={{ transition: 'stroke-dasharray 1s ease-out' }}
      />
    </svg>
  )
}
