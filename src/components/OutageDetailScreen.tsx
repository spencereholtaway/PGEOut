import { ChevronLeft } from 'lucide-react'
import OutageCard from './OutageCard'
import { formatDistance, haversine } from '../utils/distance'
import type { OutageFeature } from '../api/outages'

interface Props {
  outage: OutageFeature
  userLat: number
  userLng: number
  onBack: () => void
}

export default function OutageDetailScreen({ outage, userLat, userLng, onBack }: Props) {
  const { centroid } = outage
  const distLabel = centroid
    ? formatDistance(haversine(userLat, userLng, centroid.y, centroid.x))
    : null

  return (
    <div className="min-h-screen flex flex-col" style={{ background: 'linear-gradient(180deg, #007B97 0%, #005A7F 100%)' }}>

      {/* Header */}
      <div className="bg-white px-4 pb-4 flex items-center sticky top-0 z-10" style={{ borderRadius: '0 0 24px 24px', paddingTop: 'calc(env(safe-area-inset-top) + 12px)', boxShadow: '0 -2px 44px 0 rgba(0,0,0,0.05)' }}>
        <button
          onClick={onBack}
          aria-label="Back"
          className="flex items-center justify-center w-8 h-8 -ml-1 flex-shrink-0"
        >
          <ChevronLeft className="w-6 h-6 text-gray-700" />
        </button>
        <p className="flex-1 text-center text-gray-700 font-semibold text-base pr-7">
          Nearby Outage{distLabel ? `: ${distLabel} away` : ''}
        </p>
      </div>

      {/* Body */}
      <div className="px-4 py-6 flex flex-col gap-6">
        <OutageCard outage={outage} userLat={userLat} userLng={userLng} />
      </div>
    </div>
  )
}
