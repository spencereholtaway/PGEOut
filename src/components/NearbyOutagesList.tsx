import MiniArc from './MiniArc'
import { formatDistance, haversine } from '../utils/distance'
import type { OutageFeature } from '../api/outages'

interface Props {
  outages: OutageFeature[]
  userLat: number
  userLng: number
  onTap: (outage: OutageFeature) => void
}

export default function NearbyOutagesList({ outages, userLat, userLng, onTap }: Props) {
  if (outages.length === 0) return null

  return (
    <div>
      <p style={{ fontSize: 16, fontWeight: 600, color: '#fff', marginBottom: 12 }}>
        Nearby outages
      </p>
      <div className="flex flex-col gap-3">
        {outages.map(o => {
          const { properties: p, centroid } = o
          const isPlanned = p.OutageType === 'Planned'
          const distLabel = centroid
            ? formatDistance(haversine(userLat, userLng, centroid.y, centroid.x))
            : null

          return (
            <button
              key={p.IncidentId}
              className="card-info p-4 flex justify-between items-center w-full text-left"
              onClick={() => onTap(o)}
            >
              {/* Left: badge + distance on same row */}
              <div className="flex items-center gap-2.5">
                <div style={{ width: 110 }} className="flex">
                  <span className={`text-xs font-bold px-3 py-1 rounded-full uppercase tracking-wider ${
                    isPlanned
                      ? 'bg-green-500 text-white'
                      : 'bg-orange-400 text-white'
                  }`}>
                    {isPlanned ? 'Planned' : 'Not Planned'}
                  </span>
                </div>
                {distLabel && (
                  <span className="text-sm text-gray-400">{distLabel}</span>
                )}
              </div>

              {/* Right: mini arc */}
              <MiniArc startMs={p.StartDate} etaMs={p.EstimatedRestoreDate} />
            </button>
          )
        })}
      </div>
    </div>
  )
}
