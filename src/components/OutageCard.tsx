import ArcWidget from './ArcWidget'
import { getCauseLabel } from '../utils/causeMap'
import { formatDistance, haversine } from '../utils/distance'
import type { OutageFeature } from '../api/outages'

interface Props {
  outage: OutageFeature
  userLat: number
  userLng: number
}

const PGE_URL = 'https://pgealerts.alerts.pge.com/outagecenter/'

export default function OutageCard({ outage, userLat, userLng }: Props) {
  const { properties: p, centroid } = outage
  const isPlanned = p.OutageType === 'Planned'

  const distLabel = centroid
    ? formatDistance(haversine(userLat, userLng, centroid.y, centroid.x))
    : null

  return (
    <div className="card p-6 flex flex-col items-center gap-3">

      {/* Badge + distance */}
      <div className="flex items-center justify-center gap-2.5">
        <span className={`text-xs font-bold px-3 py-1 rounded-full uppercase tracking-wider ${
          isPlanned
            ? 'bg-green-500 text-white'
            : 'bg-orange-400 text-white'
        }`}>
          {isPlanned ? 'Planned' : 'Not Planned'}
        </span>
        {distLabel && (
          <span className="text-sm text-gray-400">{distLabel}</span>
        )}
      </div>

      {/* Cause */}
      <p className="text-sm text-gray-500 leading-snug text-center">
        {getCauseLabel(p.Cause)}
      </p>

      {/* Arc */}
      <ArcWidget startMs={p.StartDate} etaMs={p.EstimatedRestoreDate} />

      {/* Learn more */}
      <a
        href={PGE_URL}
        target="_blank"
        rel="noopener noreferrer"
        className="w-full text-white text-center rounded-full active:opacity-80 transition-opacity flex items-center justify-center gap-2 overflow-hidden"
        style={{
          background: '#2F80ED',
          border: '1px solid #2F80ED',
          borderRadius: 100,
          padding: '16px 24px',
          boxShadow: '0 2px 12px 0 rgba(47,128,237,0.20)',
          fontFamily: '"Instrument Sans"',
          fontSize: 20,
          fontWeight: 400,
          lineHeight: '19px',
          whiteSpace: 'nowrap',
          textOverflow: 'ellipsis',
        }}
      >
        Learn more at PG&amp;E
      </a>
    </div>
  )
}
