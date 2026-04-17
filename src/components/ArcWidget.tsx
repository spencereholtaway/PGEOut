import { useEffect, useState } from 'react'
import { arcFillPct, remainingMs, formatDuration } from '../utils/time'
import arcTrackLightSrc from '../assets/arc-track-light.svg'
import arcTrackDarkSrc  from '../assets/arc-track-dark.svg'
import arcFillSrc       from '../assets/arc-fill.svg'

interface Props {
  startMs: number | null
  etaMs:   number | null
}

/**
 * Pie-slice clip-path that reveals the fill arc from 9-o'clock (180°)
 * sweeping clockwise by (pct / 100) × 180°.
 *
 * Coordinates are in the fill wrapper's local space:
 *   width  ≈ 252px  (327 × (1 - 0.2286))
 *   height = 163.5px (327 × 0.5)
 * The circle centre is at (163.5, 163.5) — the bottom-centre of the wrapper.
 */
function getPieClip(pct: number): string {
  const cx = 163.5
  const cy = 163.5
  const r  = 600   // large enough to reach every corner of the wrapper
  const sweep = (Math.max(0, Math.min(100, pct)) / 100) * 180
  const STEPS = 40

  const pts = [`${cx}px ${cy}px`]
  for (let i = 0; i <= STEPS; i++) {
    const rad = ((180 + (i / STEPS) * sweep) * Math.PI) / 180
    pts.push(`${cx + r * Math.cos(rad)}px ${cy + r * Math.sin(rad)}px`)
  }
  return `polygon(${pts.join(', ')})`
}

function formatTime(ms: number): string {
  return new Date(ms)
    .toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })
    .replace('\u202f', '').replace(' ', '').toLowerCase()
}

export default function ArcWidget({ startMs, etaMs }: Props) {
  const [, setTick]   = useState(0)
  const [animated, setAnimated] = useState(false)

  useEffect(() => {
    const id = setInterval(() => setTick(t => t + 1), 30_000)
    return () => clearInterval(id)
  }, [])

  useEffect(() => {
    const id = setTimeout(() => setAnimated(true), 50)
    return () => clearTimeout(id)
  }, [])

  const ms      = etaMs ? remainingMs(etaMs) : null
  const pct     = (startMs && etaMs) ? arcFillPct(startMs, etaMs) : 0
  const animPct = animated ? pct : 0

  // All layers sit in the same grid cell (col 1, row 1) — matches Figma's
  // inline-grid / grid-cols-[max-content] / grid-rows-[max-content] pattern.
  const layer: React.CSSProperties = { gridColumn: 1, gridRow: 1 }

  const labelStyle: React.CSSProperties = {
    fontFamily: 'var(--font)',
    fontSize: 16,
    fontWeight: 300,
    color: 'var(--text-label)',
    lineHeight: 'normal',
    margin: 0,
  }

  return (
    <div style={{
      display: 'inline-grid',
      gridTemplateColumns: 'max-content',
      gridTemplateRows: 'max-content',
      alignItems: 'start',
      justifyItems: 'start',
    }}>

      {/* ── Layer 1: Track ─────────────────────────────────────────────── */}
      {/* Light mode */}
      <div
        className="dark:hidden"
        style={{ ...layer, marginLeft: 22.7, position: 'relative', width: 327, height: 327 }}
      >
        <div style={{ position: 'absolute', top: '-6.12%', right: '-6.1%', bottom: '43.88%', left: '-6.1%' }}>
          <img
            src={arcTrackLightSrc}
            aria-hidden="true"
            style={{ display: 'block', width: '100%', height: '100%', maxWidth: 'none' }}
          />
        </div>
      </div>

      {/* Dark mode */}
      <div
        className="hidden dark:block"
        style={{ ...layer, marginLeft: 22.7, position: 'relative', width: 327, height: 327 }}
      >
        <div style={{ position: 'absolute', top: '-14.68%', right: '-17.11%', bottom: '30.43%', left: '-17.11%' }}>
          <img
            src={arcTrackDarkSrc}
            aria-hidden="true"
            style={{ display: 'block', width: '100%', height: '100%', maxWidth: 'none' }}
          />
        </div>
      </div>

      {/* ── Layer 2: Fill arc ──────────────────────────────────────────── */}
      <div style={{ ...layer, marginLeft: 22.7, position: 'relative', width: 327, height: 327 }}>
        {/* clip-path sits on the wrapper div so the img inside fills it naturally */}
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: '22.86%',
            bottom: '50%',
            clipPath: getPieClip(animPct),
            transition: 'clip-path 1s ease-out',
          }}
        >
          <img
            src={arcFillSrc}
            aria-hidden="true"
            style={{ display: 'block', width: '100%', height: '100%', maxWidth: 'none' }}
          />
        </div>
      </div>

      {/* ── Layer 3: Time labels ───────────────────────────────────────── */}
      {/* Uses a nested stacking grid so ml values are relative to the outer
          grid origin — exactly as Figma specifies (ml-0 / ml-271.4). */}
      <div style={{
        ...layer,
        marginTop: 172,
        display: 'inline-grid',
        gridTemplateColumns: 'max-content',
        gridTemplateRows: 'max-content',
        alignItems: 'start',
        justifyItems: 'start',
      }}>
        {/* End-time — right-aligned at ml-271.4 */}
        {etaMs && (
          <p style={{ ...labelStyle, gridColumn: 1, gridRow: 1, marginLeft: 271.4, width: 100, textAlign: 'right' }}>
            {formatTime(etaMs)}
          </p>
        )}
        {/* Start-time — left edge at ml-0 */}
        {startMs && (
          <p style={{ ...labelStyle, gridColumn: 1, gridRow: 1, marginLeft: 0, width: 100 }}>
            {formatTime(startMs)}
          </p>
        )}
      </div>

      {/* ── Layer 4: Centre text ───────────────────────────────────────── */}
      <div style={{
        ...layer,
        marginLeft: 63.7,
        marginTop: 65,
        width: 244,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        textAlign: 'center',
      }}>
        <p style={{ fontFamily: 'var(--font)', fontSize: 16, fontWeight: 300, color: '#0089C4', lineHeight: 'normal', margin: 0, width: '100%' }}>
          Estimated fix
        </p>
        <p style={{ fontFamily: 'var(--font)', fontSize: 44, fontWeight: 300, color: '#0089C4', lineHeight: 'normal', margin: 0, width: '100%' }}>
          {etaMs ? formatDuration(ms ?? 0) : 'Unknown'}
        </p>
      </div>

    </div>
  )
}
