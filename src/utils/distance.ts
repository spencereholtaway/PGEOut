/** Haversine distance in miles between two lat/lng points */
export function haversine(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 3958.8
  const rad = Math.PI / 180
  const dLat = (lat2 - lat1) * rad
  const dLng = (lng2 - lng1) * rad
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2
  return R * 2 * Math.asin(Math.sqrt(a))
}

/** Format a raw mile distance into a display label */
export function formatDistance(miles: number): string {
  if (miles < 1) return '< 1 mi'
  return `~ ${Math.floor(miles)} mi`
}
