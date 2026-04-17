import ArcWidget from './ArcWidget'
import { getCauseLabel } from '../utils/causeMap'
import type { OutageFeature } from '../api/outages'

interface Props {
  outage:   OutageFeature
  userLat:  number
  userLng:  number
}

export default function OutageCard({ outage }: Props) {
  const { properties: p } = outage
  const isPlanned = p.OutageType === 'Planned'

  return (
    <div
      className="outage-card"
      style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center',
        height: 367, overflow: 'visible',
        paddingTop: 64, paddingBottom: 56, gap: 24,
      }}
    >
      {/* Top: badge + cause */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, width: '100%' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span className={`badge ${isPlanned ? 'badge-planned' : 'badge-unplanned'}`}>
            {isPlanned ? 'Planned' : 'Unplanned'}
          </span>
        </div>
        <p style={{
          fontFamily: 'var(--font)', fontSize: 20, fontWeight: 300,
          color: 'var(--text-content)', lineHeight: 'normal',
          textAlign: 'center', margin: 0,
        }}>
          {getCauseLabel(p.Cause)}
        </p>
      </div>

      {/* Arc widget */}
      <ArcWidget startMs={p.StartDate} etaMs={p.EstimatedRestoreDate} />
    </div>
  )
}
