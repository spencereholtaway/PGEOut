import { useRef, useEffect, useState } from 'react'
import MiniArc from './MiniArc'
import { formatDistance, haversine } from '../utils/distance'
import type { OutageFeature } from '../api/outages'

interface Props {
  outages: OutageFeature[]
  userLat: number
  userLng: number
  onTap: (outage: OutageFeature) => void
}

interface ItemProps {
  outage: OutageFeature
  index: number
  userLat: number
  userLng: number
  onTap: (outage: OutageFeature) => void
}

function NearbyOutageItem({ outage, index, userLat, userLng, onTap }: ItemProps) {
  const ref = useRef<HTMLButtonElement>(null)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) { setVisible(true); observer.disconnect() } },
      { threshold: 0.1 }
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  const { properties: p, centroid } = outage
  const isPlanned = p.OutageType === 'Planned'
  const distLabel = centroid
    ? formatDistance(haversine(userLat, userLng, centroid.y, centroid.x))
    : null

  return (
    <button
      ref={ref}
      className="card-info p-4 flex justify-between items-center w-full text-left"
      onClick={() => onTap(outage)}
      style={{
        opacity: visible ? 1 : 0,
        transform: visible ? 'translateY(0)' : 'translateY(16px)',
        transition: `opacity 0.4s ease ${index * 0.12}s, transform 0.4s ease ${index * 0.12}s`,
      }}
    >
      {/* Left: badge + distance on same row */}
      <div className="flex items-center gap-3">
        <span
          className="rounded-full px-3 py-1 whitespace-nowrap"
          style={{ background: isPlanned ? '#219653' : '#F2994A', color: '#FFF', fontFamily: '"Instrument Sans"', fontSize: 12, fontWeight: 600, textTransform: 'uppercase', textAlign: 'center' }}
        >
          {isPlanned ? 'Planned' : 'Not Planned'}
        </span>
        {distLabel && (
          <span className="text-sm text-gray-400">{distLabel}</span>
        )}
      </div>

      {/* Right: mini arc */}
      <MiniArc startMs={p.StartDate} etaMs={p.EstimatedRestoreDate} triggerAnimation={visible} />
    </button>
  )
}

export default function NearbyOutagesList({ outages, userLat, userLng, onTap }: Props) {
  if (outages.length === 0) return null

  return (
    <div>
      <p style={{ fontSize: 16, fontWeight: 600, color: '#fff', marginBottom: 12 }}>
        Nearby outages
      </p>
      <div className="flex flex-col gap-3">
        {outages.map((o, i) => (
          <NearbyOutageItem
            key={o.properties.IncidentId}
            outage={o}
            index={i}
            userLat={userLat}
            userLng={userLng}
            onTap={onTap}
          />
        ))}
      </div>
    </div>
  )
}
