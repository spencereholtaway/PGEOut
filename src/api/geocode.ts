const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search'
// California bounding box: west,south,east,north
const CA_VIEWBOX = '-124.48,32.53,-114.13,42.01'

export interface GeocodeResult {
  label: string
  lat: number
  lng: number
  state: string | null
  county: string | null
}

/** Fetch autocomplete suggestions from Nominatim (California only) */
export async function autocomplete(query: string): Promise<GeocodeResult[]> {
  if (!query.trim()) return []
  const params = new URLSearchParams({
    q:              query,
    format:         'json',
    addressdetails: '1',
    limit:          '5',
    countrycodes:   'us',
    viewbox:        CA_VIEWBOX,
    bounded:        '1',
  })
  const res = await fetch(`${NOMINATIM_URL}?${params}`, {
    headers: { 'Accept-Language': 'en' },
  })
  if (!res.ok) throw new Error('Autocomplete request failed')
  const data: any[] = await res.json()

  return data
    .filter(r => r.address?.state === 'California')
    .map((r): GeocodeResult => {
      const a = r.address
      const streetPart = a.house_number && a.road
        ? `${a.house_number} ${a.road}`
        : a.road ?? r.display_name.split(',')[0]
      const parts = [
        streetPart,
        a.city ?? a.town ?? a.village ?? a.hamlet,
        'CA',
      ].filter(Boolean)
      return {
        label:  parts.join(', '),
        lat:    parseFloat(r.lat),
        lng:    parseFloat(r.lon),
        state:  a.state ?? null,
        county: a.county?.replace(' County', '').toUpperCase() ?? null,
      }
    })
}
