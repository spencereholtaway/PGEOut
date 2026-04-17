import { useState, useEffect, useRef } from 'react'
import { Navigation } from 'lucide-react'
import { autocomplete, type GeocodeResult } from '../api/geocode'

interface Props {
  onSelect: (result: GeocodeResult) => void
  onLocation: () => void
  onDebugId?: (id: number) => void
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
    <div className="app-bg min-h-screen flex flex-col" style={{ paddingTop: 'env(safe-area-inset-top)' }}>

      {/* Input bar */}
      <div className="px-4 sticky top-0 z-10" style={{ paddingTop: 'calc(env(safe-area-inset-top) + 16px)', paddingBottom: 16, background: 'transparent' }}>
        <div className="address-pill flex items-center gap-3" style={{ padding: '12px 12px 12px 20px' }}>
          <input
            type="text"
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Your Address"
            autoFocus
            className="flex-1 bg-transparent outline-none"
            style={{ fontFamily: 'var(--font)', fontSize: 20, fontWeight: 300, color: '#0089C4', lineHeight: '25px' }}
          />
          <LocationButton onClick={onLocation} />
        </div>
      </div>

      {/* Suggestions */}
      {showSuggestions && (
        <div className="flex flex-col px-4 pt-2">
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

      {/* Empty state */}
      {!showSuggestions && (
        <div className="flex-1 flex flex-col items-center justify-center gap-8 px-10 text-center pb-20">
          <p style={{ fontFamily: 'var(--font)', fontSize: 20, fontWeight: 300, color: 'var(--text-muted)', lineHeight: '28px' }}>
            Enter your address or use<br />the location button to find<br />nearby outages.
          </p>
          <LocationButton onClick={onLocation} />
        </div>
      )}
    </div>
  )
}

function LocationButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      aria-label="Use my location"
      className="flex items-center justify-center flex-shrink-0 active:opacity-75 transition-opacity"
      style={{ width: 44, height: 44, borderRadius: '50%', background: '#0089C4', border: '1px solid #0089C4', boxShadow: '0 2px 12px 0 rgba(0,137,196,0.25)' }}
    >
      <Navigation className="w-5 h-5 text-white" />
    </button>
  )
}
