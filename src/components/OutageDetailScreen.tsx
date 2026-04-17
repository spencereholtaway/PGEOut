import { ChevronLeft } from 'lucide-react'
import OutageCard from './OutageCard'
import { formatDistance, haversine } from '../utils/distance'
import type { OutageFeature } from '../api/outages'

interface Props {
  outage:  OutageFeature
  userLat: number
  userLng: number
  onBack:  () => void
}

export default function OutageDetailScreen({ outage, userLat, userLng, onBack }: Props) {
  const { centroid } = outage
  const distLabel = centroid
    ? formatDistance(haversine(userLat, userLng, centroid.y, centroid.x))
    : null

  return (
    <div className="app-bg min-h-screen flex flex-col">

      {/* Header */}
      <div
        className="px-4 sticky top-0 z-10 flex items-center gap-3"
        style={{
          paddingTop: 'calc(env(safe-area-inset-top) + 12px)',
          paddingBottom: 12,
          background: 'transparent',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
        }}
      >
        <button
          onClick={onBack}
          aria-label="Back"
          className="flex items-center justify-center active:opacity-60 transition-opacity"
          style={{
            width: 36, height: 36, borderRadius: '50%',
            background: 'rgba(0,137,196,0.08)',
            border: '1px solid var(--stroke)',
            flexShrink: 0,
          }}
        >
          <ChevronLeft className="w-5 h-5" style={{ color: '#0089C4' }} />
        </button>

        <p style={{
          fontFamily: 'var(--font)', fontSize: 16, fontWeight: 500,
          color: 'var(--text-muted)', margin: 0, flex: 1,
        }}>
          {distLabel ? `Outage ${distLabel} away` : 'Nearby Outage'}
        </p>
      </div>

      {/* Body */}
      <div style={{ flex: 1, paddingBottom: 32 }}>
        <OutageCard outage={outage} userLat={userLat} userLng={userLng} />
      </div>
    </div>
  )
}
