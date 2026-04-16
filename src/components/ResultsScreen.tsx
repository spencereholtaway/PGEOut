import OutageCard from './OutageCard'
import NearbyOutagesList from './NearbyOutagesList'
import { Navigation } from 'lucide-react'
import { haversine } from '../utils/distance'
import type { OutageFeature } from '../api/outages'

const PGE_REPORT_URL = 'https://www.pge.com/en/contact-us/report-an-issue/report-electric-issue.html'

type ResultState = 'outages' | 'none' | 'outside' | 'error' | 'loading'

interface Props {
  state: ResultState
  outages: OutageFeature[]
  address: string
  userLat: number
  userLng: number
  lastChecked: Date | null
  onAddressTap: () => void
  onLocationTap: () => void
  nearbyOutages: OutageFeature[]
  onNearbyTap: (outage: OutageFeature) => void
}

export default function ResultsScreen({
  state, outages, address, userLat, userLng,
  lastChecked, onAddressTap, onLocationTap,
  nearbyOutages, onNearbyTap,
}: Props) {

  const sorted = [...outages].sort((a, b) => {
    const da = a.centroid ? haversine(userLat, userLng, a.centroid.y, a.centroid.x) : Infinity
    const db = b.centroid ? haversine(userLat, userLng, b.centroid.y, b.centroid.x) : Infinity
    return da - db
  })

  return (
    <div className="min-h-screen flex flex-col" style={{ background: 'linear-gradient(180deg, #007B97 0%, #005A7F 100%)' }}>

      {/* Header */}
      <div className="bg-white px-4 pb-4 flex items-start justify-between gap-3 sticky top-0 z-10" style={{ borderRadius: '0 0 24px 24px', paddingTop: 'calc(env(safe-area-inset-top) + 12px)', boxShadow: '0 -2px 44px 0 rgba(0,0,0,0.05)' }}>
        <div className="flex-1 min-w-0">
          <p className="text-xs text-gray-400 mb-0.5">Viewing outages for</p>
          <button
            onClick={onAddressTap}
            className="text-blue-500 text-sm font-medium truncate block w-full text-left"
          >
            {address}
          </button>
        </div>
        <LocationButton onClick={onLocationTap} />
      </div>

      {/* Body */}
      <div className="flex-1 px-4 flex flex-col" style={{ paddingTop: 24, paddingBottom: 24, gap: 24 }}>

        {state === 'loading' && (
          <div className="flex-1 flex items-center justify-center pt-20">
            <div className="w-8 h-8 border-4 border-blue-100 border-t-blue-500 rounded-full animate-spin" />
          </div>
        )}

        {state === 'error' && (
          <div className="card-info p-6 text-center">
            <p className="text-gray-700 font-semibold mb-1">Unable to load outages</p>
            <p className="text-sm text-gray-400">Check your connection and try again.</p>
          </div>
        )}

        {state === 'outside' && (
          <div className="card-info p-6 text-center">
            <p className="mb-2" style={{ color: '#219653', fontFamily: '"Instrument Sans"', fontSize: 24, fontWeight: 700, textAlign: 'center' }}>
              You're outside of our<br />coverage area.
            </p>
            <p className="text-sm text-gray-400">We can't report on outages for your location.</p>
          </div>
        )}

        {state === 'none' && (
          <div className="card-info p-6 text-center flex flex-col gap-4">
            <p style={{ color: '#219653', fontFamily: '"Instrument Sans"', fontSize: 24, fontWeight: 700, textAlign: 'center' }}>No outages reported</p>
            <div>
              <p className="body-text mb-3">Your local utility is not reporting any outages for your location at this time.</p>
              <p className="body-text">Many utilities refresh their data every 15 minutes. Be sure to check back again soon if you are experiencing an outage, or report one below.</p>
            </div>
            <a
              href={PGE_REPORT_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="block w-full text-white text-center rounded-full active:opacity-80 transition-opacity overflow-hidden"
              style={{
                background: '#2F80ED',
                border: '1px solid #2F80ED',
                borderRadius: 100,
                padding: '14px 24px',
                boxShadow: '0 2px 12px 0 rgba(47,128,237,0.20)',
                fontFamily: '"Instrument Sans"',
                fontSize: 16,
                fontWeight: 400,
                lineHeight: '24px',
              }}
            >
              Report an outage to PG&amp;E
            </a>
          </div>
        )}

        {state === 'outages' && sorted[0] && (
          <OutageCard
            outage={sorted[0]}
            userLat={userLat}
            userLng={userLng}
          />
        )}

        {(state === 'outages' || state === 'none') && nearbyOutages.length > 0 && (
          <NearbyOutagesList
            outages={nearbyOutages}
            userLat={userLat}
            userLng={userLng}
            onTap={onNearbyTap}
          />
        )}

        {lastChecked && state !== 'loading' && (
          <p className="text-center text-xs" style={{ color: '#ffffff' }}>
            Last updated {lastChecked.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
          </p>
        )}
      </div>
    </div>
  )
}

function LocationButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      aria-label="Use my location"
      className="w-12 h-12 rounded-full flex items-center justify-center flex-shrink-0 active:opacity-80 transition-opacity"
      style={{
        background: '#2F80ED',
        border: '1px solid #2F80ED',
        boxShadow: '0 2px 12px 0 rgba(47,128,237,0.20)',
      }}
    >
      <Navigation className="w-5 h-5 text-white" />
    </button>
  )
}
