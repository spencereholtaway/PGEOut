import { useEffect, useRef, useState } from 'react'
import MiniArc from './MiniArc'
import { formatDistance, haversine } from '../utils/distance'
import { formatDuration, remainingMs } from '../utils/time'
import type { OutageFeature } from '../api/outages'
import pinIconLight from '../assets/icon-pin.svg'
import pinIconDark  from '../assets/icon-pin-dark.svg'

interface Props {
  outages:  OutageFeature[]
  userLat:  number
  userLng:  number
  onTap: (outage: OutageFeature) => void
}

function OutageRow({
  outage, userLat, userLng, onTap,
}: {
  outage: OutageFeature
  userLat: number
  userLng: number
  onTap: (o: OutageFeature) => void
}) {
  const ref = useRef<HTMLButtonElement>(null)
  const [triggered, setTriggered] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) { setTriggered(true); observer.disconnect() } },
      { threshold: 0.3 },
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  const { properties: p, centroid } = outage
  const isPlanned  = p.OutageType === 'Planned'
  const distLabel  = centroid ? formatDistance(haversine(userLat, userLng, centroid.y, centroid.x)) : null
  const ms         = p.EstimatedRestoreDate ? remainingMs(p.EstimatedRestoreDate) : null
  const timeLabel  = ms !== null ? formatDuration(ms) : null

  return (
    <button
      ref={ref}
      key={p.IncidentId}
      className="nearby-card active:opacity-75 transition-opacity"
      style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: 16, gap: 16, width: '100%', textAlign: 'left', cursor: 'pointer',
      }}
      onClick={() => onTap(outage)}
    >
      {/* Left: pin icon + distance */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
        <picture style={{ width: 16, height: 16, flexShrink: 0, display: 'block' }}>
          <source srcSet={pinIconDark}  media="(prefers-color-scheme: dark)" />
          <img src={pinIconLight} alt="" style={{ width: 16, height: 16, display: 'block' }} />
        </picture>
        <span style={{ fontFamily: 'var(--font)', fontSize: 16, fontWeight: 400, color: 'var(--text-content)', whiteSpace: 'nowrap' }}>
          {distLabel ?? '\u2014'}
        </span>
      </div>

      {/* Centre: badge */}
      <span className={`badge ${isPlanned ? 'badge-planned' : 'badge-unplanned'}`}>
        {isPlanned ? 'Planned' : 'Unplanned'}
      </span>

      {/* Right: time + mini arc */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
        {timeLabel && (
          <span style={{ fontFamily: 'var(--font)', fontSize: 14, fontWeight: 400, color: 'var(--text-content)', whiteSpace: 'nowrap', textAlign: 'right', width: 60 }}>
            {timeLabel}
          </span>
        )}
        <MiniArc
          startMs={p.StartDate}
          etaMs={p.EstimatedRestoreDate}
          isPlanned={isPlanned}
          triggerAnimation={triggered}
        />
      </div>
    </button>
  )
}

export default function NearbyOutagesList({ outages, userLat, userLng, onTap }: Props) {
  if (outages.length === 0) return null

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24, paddingTop: 64, paddingBottom: 64 }}>
      <p style={{
        fontFamily: 'var(--font)', fontSize: 16, fontWeight: 500,
        color: 'var(--text-label)', lineHeight: 'normal', margin: 0, textAlign: 'center',
      }}>
        Nearby Outages
      </p>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {outages.map(outage => (
          <OutageRow
            key={outage.properties.IncidentId}
            outage={outage}
            userLat={userLat}
            userLng={userLng}
            onTap={onTap}
          />
        ))}
      </div>
    </div>
  )
}
