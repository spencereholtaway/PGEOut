import { useEffect, useState } from 'react'
import { arcFillPct, remainingMs, formatDuration } from '../utils/time'

interface Props {
  startMs: number | null
  etaMs: number | null
}

// Gauge geometry
const SIZE   = 220
const STROKE = 20
const R      = (SIZE - STROKE) / 2   // 100
const CX     = SIZE / 2              // 110
const CY     = SIZE / 2              // 110

const CIRCUMFERENCE   = 2 * Math.PI * R
const ARC_DEG         = 240
const ARC_LENGTH      = CIRCUMFERENCE * (ARC_DEG / 360)
const GAP_LENGTH      = CIRCUMFERENCE - ARC_LENGTH
const START_ANGLE_DEG = 150
const END_ANGLE_DEG   = START_ANGLE_DEG + ARC_DEG  // 390 = 30°

const ROTATE = `rotate(${START_ANGLE_DEG}, ${CX}, ${CY})`

const SVG_HEIGHT = SIZE

function angleToXY(deg: number) {
  const rad = (deg * Math.PI) / 180
  return { x: CX + R * Math.cos(rad), y: CY + R * Math.sin(rad) }
}

function formatTime(ms: number): string {
  return new Date(ms)
    .toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })
    .replace('\u202f', '')   // narrow no-break space some browsers insert
    .replace(' ', '')
    .toLowerCase()
}

export default function ArcWidget({ startMs, etaMs }: Props) {
  const [, setTick] = useState(0)
  const [animated, setAnimated] = useState(false)

  useEffect(() => {
    const id = setInterval(() => setTick(t => t + 1), 30_000)
    return () => clearInterval(id)
  }, [])

  useEffect(() => {
    const id = setTimeout(() => setAnimated(true), 50)
    return () => clearTimeout(id)
  }, [])

  const ms        = etaMs ? remainingMs(etaMs) : null
  const isOverdue = ms === 0
  const pct       = (startMs && etaMs) ? arcFillPct(startMs, etaMs) : 0
  const fillLen   = animated ? (pct / 100) * ARC_LENGTH : 0

  const arcColor  = pct >= 67 ? '#219653' : pct >= 34 ? '#F2994A' : '#EB5757'

  const trackDash = `${ARC_LENGTH} ${GAP_LENGTH}`
  const fillDash  = `${fillLen} ${CIRCUMFERENCE - fillLen}`

  // Dot at end of fill — always positioned at arc start, rotated via CSS to match fill
  const dot = angleToXY(START_ANGLE_DEG)

  // Arc endpoint positions for timestamp labels
  const startPt = angleToXY(START_ANGLE_DEG)
  const endPt   = angleToXY(END_ANGLE_DEG)
  const labelY  = startPt.y + STROKE / 2 + 16

  return (
    <div className="flex flex-col items-center w-full">
      {/* Arc + overlaid text */}
      <div className="relative" style={{ width: SIZE, height: SVG_HEIGHT }}>
        <svg width={SIZE} height={SVG_HEIGHT} viewBox={`0 0 ${SIZE} ${SVG_HEIGHT}`}>
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
            strokeLinecap="round" strokeDasharray={fillDash}
            transform={ROTATE}
            style={{ transition: 'stroke-dasharray 1s ease-out' }}
          />
          {/* Dot marker — rotates with the fill animation */}
          {(startMs && etaMs) && (
            <circle
              cx={dot.x} cy={dot.y} r={STROKE / 2} fill={arcColor}
              style={{
                transformOrigin: `${CX}px ${CY}px`,
                transform: `rotate(${animated ? (pct / 100) * ARC_DEG : 0}deg)`,
                transition: 'transform 1s ease-out',
              }}
            />
          )}
          {/* Start time — anchored under left arc end */}
          {startMs && (
            <text
              x={startPt.x} y={labelY}
              textAnchor="middle"
              fill="#9CA3AF" fontSize="13"
              fontFamily="Instrument Sans, system-ui, sans-serif"
            >
              {formatTime(startMs)}
            </text>
          )}
          {/* ETA time — anchored under right arc end */}
          {etaMs && (
            <text
              x={endPt.x} y={labelY}
              textAnchor="middle"
              fill="#9CA3AF" fontSize="13"
              fontFamily="Instrument Sans, system-ui, sans-serif"
            >
              {formatTime(etaMs)}
            </text>
          )}
        </svg>

        {/* Centre text */}
        <div className="absolute inset-0 flex flex-col items-center justify-center pb-4" style={{ height: SIZE }}>
          <span className="text-sm text-gray-400 leading-snug text-center">Expected<br />Restoration</span>
          <span className="text-3xl font-bold text-gray-800 leading-none mt-1">
            {etaMs ? formatDuration(ms ?? 0) : 'Unknown'}
          </span>
        </div>
      </div>

      {/* Overdue subtext */}
      {isOverdue && etaMs && (
        <p className="text-xs text-gray-400 text-center mt-1 px-6 leading-relaxed">
          Your utility is working on the outage past the estimated restoration time.
        </p>
      )}
    </div>
  )
}
