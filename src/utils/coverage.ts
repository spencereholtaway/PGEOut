const NON_PGE_COUNTIES = new Set([
  'LOS ANGELES', 'SAN DIEGO', 'ORANGE', 'RIVERSIDE',
  'SAN BERNARDINO', 'IMPERIAL', 'VENTURA',
])

/**
 * Returns true if the location is within PG&E's service territory.
 * @param state  State name from Photon geocoder (e.g. "California")
 * @param county County name from Photon geocoder (e.g. "Los Angeles County")
 */
export function isInPGETerritory(state: string | null, county: string | null): boolean {
  if (!state || state.toLowerCase() !== 'california') return false
  if (!county) return true // assume PG&E if we can't determine county
  const countyUpper = county.toUpperCase().replace(' COUNTY', '').trim()
  return !NON_PGE_COUNTIES.has(countyUpper)
}
