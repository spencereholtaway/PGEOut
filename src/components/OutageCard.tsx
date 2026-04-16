import ArcWidget from './ArcWidget'
import { getCauseLabel } from '../utils/causeMap'
import type { OutageFeature } from '../api/outages'

interface Props {
  outage: OutageFeature
  userLat: number
  userLng: number
}

const PGE_URL = 'https://pgealerts.alerts.pge.com/outagecenter/'

export default function OutageCard({ outage }: Props) {
  const { properties: p } = outage
  const isPlanned = p.OutageType === 'Planned'
  const isOverdue = p.EstimatedRestoreDate !== null && p.EstimatedRestoreDate <= Date.now()

  return (
    <div className="card p-6 flex flex-col items-center gap-4">

      {/* Badge */}
      <div className="flex items-center justify-center">
        <span
          className="text-xs font-bold px-3 py-1 rounded-full uppercase tracking-wider text-white"
          style={{ background: isPlanned ? '#219653' : '#F2994A' }}
        >
          {isPlanned ? 'Planned' : 'Not Planned'}
        </span>
      </div>

      {/* Cause */}
      <p className="text-sm text-gray-500 leading-snug text-center">
        {getCauseLabel(p.Cause)}
      </p>

      {/* Arc */}
      <ArcWidget startMs={p.StartDate} etaMs={p.EstimatedRestoreDate} />

      {/* Overdue subtext */}
      {isOverdue && (
        <p className="text-center px-2 leading-relaxed" style={{ fontSize: 14, color: '#4F4F4F', marginTop: -16 }}>
          Your utility is working on the outage past the estimated restoration time.
        </p>
      )}

      {/* Learn more */}
      <a
        href={PGE_URL}
        target="_blank"
        rel="noopener noreferrer"
        className="btn-primary active:opacity-80 transition-opacity"
      >
        Learn more at PG&amp;E
      </a>
    </div>
  )
}
