import { useState, useEffect, useRef } from 'react'
import { Navigation } from 'lucide-react'
import { autocomplete, type GeocodeResult } from '../api/geocode'

interface Props {
  onSelect: (result: GeocodeResult) => void
  onLocation: () => void
  onDebugId?: (id: number) => void
}

export default function SearchScreen({ onSelect, onLocation, onDebugId }: Props) {
  const [query, setQuery]           = useState('')
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
  const debugId = debugMatch ? parseInt(debugMatch[1], 10) : null

  const showSuggestions = suggestions.length > 0 || debugId !== null

  return (
    <div className="min-h-screen flex flex-col" style={{ background: 'linear-gradient(180deg, #007B97 0%, #005A7F 100%)' }}>

      {/* Input row — fixed at top */}
      <div className="px-4 pt-14 pb-5 bg-white sticky top-0 z-10" style={{ borderRadius: '0 0 24px 24px' }}>
        <div className="flex items-center gap-3">
          <input
            type="text"
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Your Address"
            autoFocus
            className="flex-1 border-2 border-blue-400 rounded-full px-5 py-3 text-sm outline-none focus:border-blue-500 placeholder-gray-400 bg-white"
          />
          <LocationButton onClick={onLocation} />
        </div>
      </div>

      {/* Autocomplete list */}
      {showSuggestions && (
        <div className="flex flex-col">
          {debugId !== null ? (
            <button
              onClick={() => { setSuggestions([]); onDebugId?.(debugId) }}
              className="text-left px-5 py-4 text-sm text-white border-b border-white/20 active:bg-white/10"
            >
              🔍 Fetch outage #{debugId}
            </button>
          ) : suggestions.map((s, i) => (
            <button
              key={i}
              onClick={() => handleSelect(s)}
              className="text-left px-5 py-4 text-sm text-white border-b border-white/20 active:bg-white/10"
            >
              {s.label}
            </button>
          ))}
        </div>
      )}

      {/* Null state — vertically centred in remaining space */}
      {!showSuggestions && (
        <div className="flex-1 flex flex-col items-center justify-center gap-7 px-10 text-center pb-16">
          <p className="body-text" style={{ color: '#ffffff' }}>
            Enter your address or<br />use the location button<br />to find nearby outages.
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
