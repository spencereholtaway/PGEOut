import { useState, useEffect, useRef, useCallback } from 'react'
import SearchScreen from './components/SearchScreen'
import ResultsScreen from './components/ResultsScreen'
import OutageDetailScreen from './components/OutageDetailScreen'
import { fetchIds, fetchById, spatialQuery, nearbyQuery, type OutageFeature } from './api/outages'
import { type GeocodeResult } from './api/geocode'
import { isInPGETerritory } from './utils/coverage'
import { haversine } from './utils/distance'
import './index.css'

const REFRESH_MS = 15 * 60 * 1000
const STORAGE_KEY = 'pge-last-location'

function saveLocation(loc: UserLocation) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(loc))
}

function loadLocation(): UserLocation | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? (JSON.parse(raw) as UserLocation) : null
  } catch {
    return null
  }
}

type Screen = 'search' | 'results' | 'detail'
type ResultState = 'outages' | 'none' | 'outside' | 'error' | 'loading'

interface UserLocation {
  lat: number
  lng: number
  label: string
  state: string | null
  county: string | null
}

function setsEqual(a: Set<number>, b: Set<number>): boolean {
  if (a.size !== b.size) return false
  for (const v of a) if (!b.has(v)) return false
  return true
}

export default function App() {
  const saved = loadLocation()
  const [screen, setScreen] = useState<Screen>(saved ? 'results' : 'search')
  const [userLoc, setUserLoc] = useState<UserLocation | null>(saved)
  const [resultState, setResultState] = useState<ResultState>('loading')
  const [outages, setOutages] = useState<OutageFeature[]>([])
  const [lastChecked, setLastChecked] = useState<Date | null>(null)

  const [nearbyOutages, setNearbyOutages] = useState<OutageFeature[]>([])
  const [selectedOutage, setSelectedOutage] = useState<OutageFeature | null>(null)

  const prevIdsRef = useRef<Set<number>>(new Set())
  const refreshTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const userLocRef = useRef<UserLocation | null>(null)
  const debugModeRef = useRef(false)
  userLocRef.current = userLoc

  const runQuery = useCallback(async (loc: UserLocation) => {
    if (!isInPGETerritory(loc.state, loc.county)) {
      setResultState('outside')
      return
    }
    setResultState('loading')
    try {
      const results = await spatialQuery(loc.lat, loc.lng)
      setOutages(results)
      setResultState(results.length > 0 ? 'outages' : 'none')

      // Fetch nearby outages (within 50 mi), deduplicate against current results
      try {
        const currentIds = new Set(results.map(o => o.properties.IncidentId))
        const nearby = await nearbyQuery(loc.lat, loc.lng)
        const filtered = nearby
          .filter(o => !currentIds.has(o.properties.IncidentId))
          .sort((a, b) => {
            const da = a.centroid ? haversine(loc.lat, loc.lng, a.centroid.y, a.centroid.x) : Infinity
            const db = b.centroid ? haversine(loc.lat, loc.lng, b.centroid.y, b.centroid.x) : Infinity
            return da - db
          })
          .slice(0, 3)
        setNearbyOutages(filtered)
      } catch {
        // nearby fetch failure is non-critical
      }
    } catch {
      setResultState('error')
    }
  }, [])

  const scheduleRefresh = useCallback(() => {
    if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current)
    refreshTimerRef.current = setTimeout(async () => {
      try {
        const newIds = await fetchIds()
        const changed = !setsEqual(newIds, prevIdsRef.current)
        if (changed && !debugModeRef.current) {
          prevIdsRef.current = newIds
          const loc = userLocRef.current
          if (loc) await runQuery(loc)
        }
        setLastChecked(new Date())
      } catch {
        // silently skip failed refresh
      }
      scheduleRefresh()
    }, REFRESH_MS)
  }, [runQuery])

  // On mount, re-query if we restored a saved location
  useEffect(() => {
    if (saved) {
      runQuery(saved).then(() => setLastChecked(new Date()))
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Start refresh loop when on results screen
  useEffect(() => {
    if (screen !== 'results') return
    scheduleRefresh()
    return () => { if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current) }
  }, [screen, scheduleRefresh])

  async function handleSelect(result: GeocodeResult) {
    debugModeRef.current = false
    const loc: UserLocation = {
      lat: result.lat, lng: result.lng,
      label: result.label,
      state: result.state,
      county: result.county,
    }
    setUserLoc(loc)
    saveLocation(loc)
    setScreen('results')
    await runQuery(loc)
    setLastChecked(new Date())
  }

  async function handleLocation() {
    if (!navigator.geolocation) {
      alert('Geolocation is not supported by your browser.')
      return
    }
    navigator.geolocation.getCurrentPosition(
      async ({ coords }) => {
        // GPS location: assume California, territory check via runQuery
        const loc: UserLocation = {
          lat: coords.latitude,
          lng: coords.longitude,
          label: 'Your location',
          state: 'California',
          county: null,
        }
        debugModeRef.current = false
        setUserLoc(loc)
        saveLocation(loc)
        setScreen('results')
        await runQuery(loc)
        setLastChecked(new Date())
      },
      () => alert('Location access denied. Please enter an address.'),
    )
  }

  function handleNearbyTap(outage: OutageFeature) {
    setSelectedOutage(outage)
    setScreen('detail')
  }

  function handleBackFromDetail() {
    setScreen('results')
    setSelectedOutage(null)
  }

  async function handleDebugId(id: number) {
    debugModeRef.current = true
    setUserLoc(null)
    setScreen('results')
    setResultState('loading')
    try {
      const results = await fetchById(id)
      setOutages(results)
      setResultState(results.length > 0 ? 'outages' : 'none')
    } catch {
      setResultState('error')
    }
    setLastChecked(new Date())
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {screen === 'search' && (
        <SearchScreen onSelect={handleSelect} onLocation={handleLocation} onDebugId={handleDebugId} />
      )}
      {screen === 'results' && (
        <ResultsScreen
          state={resultState}
          outages={outages}
          address={userLoc?.label ?? ''}
          userLat={userLoc?.lat ?? 0}
          userLng={userLoc?.lng ?? 0}
          lastChecked={lastChecked}
          onAddressTap={() => setScreen('search')}
          onLocationTap={handleLocation}
          nearbyOutages={nearbyOutages}
          onNearbyTap={handleNearbyTap}
        />
      )}
      {screen === 'detail' && selectedOutage && (
        <OutageDetailScreen
          outage={selectedOutage}
          userLat={userLoc?.lat ?? 0}
          userLng={userLoc?.lng ?? 0}
          onBack={handleBackFromDetail}
        />
      )}
    </div>
  )
}
