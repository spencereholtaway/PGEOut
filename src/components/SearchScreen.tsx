import { useState, useEffect, useRef } from 'react'
import { Navigation } from 'lucide-react'
import pgeLogo from '../assets/pge-logo.png'
import { autocomplete, type GeocodeResult } from '../api/geocode'

interface Props {
  onSelect:    (result: GeocodeResult) => void
  onLocation:  () => void
  onDebugId?:  (id: number) => void
}

export default function SearchScreen({ onSelect, onLocation, onDebugId }: Props) {
  const [query, setQuery]             = useState('')
  const [suggestions, setSuggestions] = useState<GeocodeResult[]>([])
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    if (!query.trim()) { setSuggestions([]); return }

    debounceRef.current = setTimeout(async () => {
      try { setSuggestions(await autocomplete(query)) }
      catch { setSuggestions([]) }
    }, 300)

    return () => { if (debounceRef.current) clearTimeout(debounceRef.current) }
  }, [query])

  function handleSelect(result: GeocodeResult) {
    setQuery(result.label)
    setSuggestions([])
    onSelect(result)
  }

  const debugMatch = query.match(/^#(\d+)$/)
  const debugId    = debugMatch ? parseInt(debugMatch[1], 10) : null
  const showSuggestions = suggestions.length > 0 || debugId !== null

  return (
    <div className="app-bg min-h-screen flex flex-col">

      {/* Rectangle 2 — only on empty state, not when suggestions are showing */}
      {!showSuggestions && <div className="sticky-gradient" />}

      {/* Sticky header — spec 70:189: h-[158px] flex-col gap-[16px] justify-end px-[16px] */}
      <div
        className="sticky top-0 z-10"
        style={{
          height: 'calc(158px + env(safe-area-inset-top))',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'flex-end',
          gap: 16,
          paddingBottom: 16,
          paddingLeft: 16,
          paddingRight: 16,
        }}
      >
        {/* PG&E logo + label — spec 70:190 */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <img src={pgeLogo} alt="PG&E" style={{ width: 32, height: 34, flexShrink: 0 }} />
          <span style={{ fontFamily: 'var(--font)', fontSize: 24, fontWeight: 400, color: 'var(--text-muted)', lineHeight: 'normal', flex: 1 }}>
            Search for Outages
          </span>
        </div>

        {/* Address input pill — spec 70:197 */}
        <div
          className="address-pill w-full"
          style={{ display: 'flex', alignItems: 'center', padding: '16px 20px 16px 16px', borderRadius: 1000 }}
        >
          <input
            type="text"
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Your Address"
            autoFocus
            className="flex-1 bg-transparent outline-none"
            style={{ fontFamily: 'var(--font)', fontSize: 32, fontWeight: 300, color: '#0089C4', lineHeight: 'normal' }}
          />
        </div>
      </div>

      {/* Suggestions */}
      {showSuggestions && (
        <div className="flex flex-col px-4 pt-2" style={{ position: 'relative', zIndex: 1 }}>
          {debugId !== null ? (
            <button
              onClick={() => { setSuggestions([]); onDebugId?.(debugId) }}
              className="text-left py-4 border-b active:opacity-60 transition-opacity"
              style={{ fontFamily: 'var(--font)', fontSize: 16, fontWeight: 400, color: 'var(--primary)', borderColor: 'rgba(0,137,196,0.15)' }}
            >
              🔍 Fetch outage #{debugId}
            </button>
          ) : suggestions.map((s, i) => (
            <button
              key={i}
              onClick={() => handleSelect(s)}
              className="text-left py-4 border-b active:opacity-60 transition-opacity"
              style={{ fontFamily: 'var(--font)', fontSize: 16, fontWeight: 400, color: 'var(--text-muted)', borderColor: 'rgba(0,137,196,0.15)' }}
            >
              {s.label}
            </button>
          ))}
        </div>
      )}

      {/* Empty state — spec 70:204: text + location button */}
      {!showSuggestions && (
        <div
          className="flex-1 flex flex-col items-center justify-center gap-6 text-center"
          style={{ paddingBottom: 80 }}
        >
          <p style={{
            fontFamily: "'Instrument Sans', system-ui, sans-serif",
            fontSize: 23,
            fontWeight: 400,
            color: '#777',
            lineHeight: 'normal',
            margin: 0,
          }}>
            Enter your address or<br />
            use the location button<br />
            to find nearby outages.
          </p>
          <LocationButton onClick={onLocation} />
        </div>
      )}
    </div>
  )
}

/* spec 70:206: 64×64px, #2F80ED, shadow rgba(47,128,237,0.2) */
function LocationButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      aria-label="Use my location"
      className="flex items-center justify-center flex-shrink-0 active:opacity-75 transition-opacity"
      style={{
        width: 64, height: 64,
        borderRadius: '100px',
        background: '#2F80ED',
        border: '1px solid #2F80ED',
        boxShadow: '0px 2px 12px 0px rgba(47,128,237,0.2)',
      }}
    >
      <Navigation className="w-6 h-6 text-white" />
    </button>
  )
}
