import pgeLogo    from '../assets/pge-logo.png'
import menuIcon   from '../assets/icon-menu.svg'
import pencilIcon from '../assets/icon-pencil.svg'
import externalIcon from '../assets/icon-external.svg'
import OutageCard from './OutageCard'
import NearbyOutagesList from './NearbyOutagesList'
import { haversine } from '../utils/distance'
import type { OutageFeature } from '../api/outages'

const PGE_REPORT_URL = 'https://www.pge.com/en/contact-us/report-an-issue/report-electric-issue.html'

type ResultState = 'outages' | 'none' | 'outside' | 'error' | 'loading'

interface Props {
  state:           ResultState
  outages:         OutageFeature[]
  address:         string
  userLat:         number
  userLng:         number
  lastChecked:     Date | null
  onAddressTap:    () => void
  onLocationTap:   () => void
  nearbyOutages:   OutageFeature[]
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

  // Split address into street + city for display
  const parts      = address.split(',')
  const streetPart = parts[0]?.trim() ?? address
  const cityPart   = parts.slice(1).join(',').trim()

  void onLocationTap

  return (
    <div className="app-bg min-h-screen flex flex-col">

      {/* Rectangle 2 — spec 59:170: 290px gradient fade, sits over scroll content */}
      <div className="sticky-gradient" />

      {/* Sticky header — spec 59:171: h-[222px] flex-col gap-[16px] justify-end px-[16px] */}
      <div
        className="sticky top-0 z-10"
        style={{
          height: '222px',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'flex-end',
          gap: 16,
          paddingTop: 'env(safe-area-inset-top)',
          paddingLeft: 16,
          paddingRight: 16,
        }}
      >
        {/* "Outages affecting" label row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <img src={pgeLogo} alt="PG&E" style={{ width: 32, height: 34, flexShrink: 0 }} />
          <span style={{ fontFamily: 'var(--font)', fontSize: 24, fontWeight: 400, color: 'var(--text-muted)', lineHeight: 'normal', flex: 1 }}>
            Outages affecting
          </span>
          <img src={menuIcon} alt="Menu" style={{ width: 24, height: 24, flexShrink: 0 }} />
        </div>

        {/* Address pill — tappable */}
        <button
          onClick={onAddressTap}
          className="address-pill active:opacity-75 transition-opacity w-full text-left"
          style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, padding: '16px 20px 16px 16px' }}
        >
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{ fontFamily: 'var(--font)', fontSize: 32, fontWeight: 300, color: '#0089C4', lineHeight: 'normal', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {streetPart}
            </p>
            {cityPart && (
              <p style={{ fontFamily: 'var(--font)', fontSize: 16, fontWeight: 400, color: '#0089C4', lineHeight: 'normal', margin: 0 }}>
                {cityPart}
              </p>
            )}
          </div>
          <img src={pencilIcon} alt="Edit" style={{ width: 24, height: 24, flexShrink: 0 }} />
        </button>
      </div>

      {/* Body */}
      <div className="flex-1 flex flex-col" style={{ position: 'relative', zIndex: 1 }}>

        {state === 'loading' && (
          <div className="flex-1 flex items-center justify-center pt-20">
            <div className="w-8 h-8 border-4 border-t-transparent rounded-full animate-spin" style={{ borderColor: 'rgba(0,137,196,0.2)', borderTopColor: '#0089C4' }} />
          </div>
        )}

        {state === 'error' && (
          <div className="mx-4 mt-6 p-6 text-center" style={{ background: '#fff', borderRadius: 16, border: '1px solid var(--stroke)' }}>
            <p style={{ fontFamily: 'var(--font)', fontWeight: 500, color: '#333', marginBottom: 4 }}>Unable to load outages</p>
            <p style={{ fontFamily: 'var(--font)', fontSize: 14, color: 'var(--text-muted)' }}>Check your connection and try again.</p>
          </div>
        )}

        {state === 'outside' && (
          <div className="mx-4 mt-6 p-6" style={{ background: '#fff', borderRadius: 16, border: '1px solid var(--stroke)' }}>
            <p style={{ fontFamily: 'var(--font)', fontSize: 20, fontWeight: 500, color: 'var(--planned)', marginBottom: 8 }}>
              You're outside our coverage area.
            </p>
            <p style={{ fontFamily: 'var(--font)', fontSize: 16, fontWeight: 300, color: 'var(--text-muted)' }}>
              We can't report on outages for your location.
            </p>
          </div>
        )}

        {state === 'none' && (
          <div className="mx-4 mt-6 p-6" style={{ background: '#fff', borderRadius: 16, border: '1px solid var(--stroke)' }}>
            <p style={{ fontFamily: 'var(--font)', fontSize: 20, fontWeight: 500, color: 'var(--planned)', marginBottom: 8 }}>
              No outages reported
            </p>
            <p style={{ fontFamily: 'var(--font)', fontSize: 16, fontWeight: 300, color: 'var(--text-muted)', lineHeight: '22px' }}>
              Your local utility is not reporting any outages for your location at this time. Many utilities refresh every 15 minutes — check back soon if you're experiencing an outage.
            </p>
          </div>
        )}

        {state === 'outages' && sorted[0] && (
          <OutageCard outage={sorted[0]} userLat={userLat} userLng={userLng} />
        )}

        {/* Nearby outages */}
        {(state === 'outages' || state === 'none') && nearbyOutages.length > 0 && (
          <div className="mx-4">
            <NearbyOutagesList outages={nearbyOutages} userLat={userLat} userLng={userLng} onTap={onNearbyTap} />
          </div>
        )}

        {/* Report button + footer */}
        {state !== 'loading' && (
          <div
            className="mx-4"
            style={{
              display: 'flex', flexDirection: 'column', alignItems: 'center',
              paddingTop: 32, paddingBottom: 32, gap: 56,
            }}
          >
            <a href={PGE_REPORT_URL} target="_blank" rel="noopener noreferrer" className="btn-report">
              Report an outage
              <img src={externalIcon} alt="" style={{ width: 16, height: 16 }} />
            </a>
            <p style={{ fontFamily: 'var(--font)', fontSize: 12, fontWeight: 300, color: 'var(--text-label)', textAlign: 'center' }}>
              Designed and built (with Claude), Spencer Holtaway 2026
            </p>
          </div>
        )}

        {lastChecked && state !== 'loading' && (
          <p style={{ fontFamily: 'var(--font)', fontSize: 12, color: 'var(--text-subtle)', textAlign: 'center', paddingBottom: 16 }}>
            Last updated {lastChecked.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
          </p>
        )}
      </div>
    </div>
  )
}
