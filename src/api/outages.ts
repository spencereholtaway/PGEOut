const BASE = 'https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services/Power_Outages_(View)/FeatureServer/1'

export interface OutageProperties {
  IncidentId: string
  OutageType: 'Planned' | 'Not Planned'
  Cause: string | null
  ImpactedCustomers: number | null
  County: string | null
  StartDate: number | null
  EstimatedRestoreDate: number | null
}

export interface OutageCentroid {
  x: number // lng
  y: number // lat
}

export interface OutageFeature {
  type: 'Feature'
  properties: OutageProperties
  centroid: OutageCentroid | null
}

/** Fetch just the OBJECTID list for change detection */
export async function fetchIds(): Promise<Set<number>> {
  const res = await fetch(`${BASE}/query?where=1%3D1&returnIdsOnly=true&f=json`)
  if (!res.ok) throw new Error('Failed to fetch outage IDs')
  const data = await res.json()
  return new Set<number>(data.objectIds ?? [])
}

/** Fetch all PG&E outage polygons with centroids */
export async function fetchOutages(): Promise<OutageFeature[]> {
  const params = new URLSearchParams({
    where: '1=1',
    outFields: 'IncidentId,OutageType,Cause,ImpactedCustomers,County,StartDate,EstimatedRestoreDate',
    returnGeometry: 'false',
    returnCentroid: 'true',
    outSR: '4326',
    f: 'json',
    resultRecordCount: '2000',
  })
  const res = await fetch(`${BASE}/query?${params}`)
  if (!res.ok) throw new Error('Failed to fetch outages')
  const data = await res.json()

  // Deduplicate by IncidentId (API returns every record twice)
  const seen = new Set<string>()
  const features: OutageFeature[] = []

  for (const f of data.features ?? []) {
    const id = String(f.attributes.IncidentId)
    if (seen.has(id)) continue
    seen.add(id)
    features.push({
      type: 'Feature',
      properties: {
        IncidentId:            String(f.attributes.IncidentId),
        OutageType:            f.attributes.OutageType,
        Cause:                 f.attributes.Cause ?? null,
        ImpactedCustomers:     f.attributes.ImpactedCustomers ?? null,
        County:                f.attributes.County ?? null,
        StartDate:             f.attributes.StartDate ?? null,
        EstimatedRestoreDate:  f.attributes.EstimatedRestoreDate ?? null,
      },
      centroid: f.centroid
        ? { x: f.centroid.x, y: f.centroid.y }
        : null,
    })
  }

  return features
}

/** Fetch a single outage by IncidentId (debug tool) */
export async function fetchById(incidentId: number): Promise<OutageFeature[]> {
  const params = new URLSearchParams({
    where:          `IncidentId=${incidentId}`,
    outFields:      'IncidentId,OutageType,Cause,ImpactedCustomers,County,StartDate,EstimatedRestoreDate',
    returnGeometry: 'false',
    returnCentroid: 'true',
    outSR:          '4326',
    f:              'json',
  })
  const res = await fetch(`${BASE}/query?${params}`)
  if (!res.ok) throw new Error('fetchById failed')
  const data = await res.json()

  const seen = new Set<string>()
  const features: OutageFeature[] = []
  for (const f of data.features ?? []) {
    const id = String(f.attributes.IncidentId)
    if (seen.has(id)) continue
    seen.add(id)
    features.push({
      type: 'Feature',
      properties: {
        IncidentId:           String(f.attributes.IncidentId),
        OutageType:           f.attributes.OutageType,
        Cause:                f.attributes.Cause ?? null,
        ImpactedCustomers:    f.attributes.ImpactedCustomers ?? null,
        County:               f.attributes.County ?? null,
        StartDate:            f.attributes.StartDate ?? null,
        EstimatedRestoreDate: f.attributes.EstimatedRestoreDate ?? null,
      },
      centroid: f.centroid ? { x: f.centroid.x, y: f.centroid.y } : null,
    })
  }
  return features
}

/** Nearby query — returns outages within 50 miles of a point */
export async function nearbyQuery(lat: number, lng: number): Promise<OutageFeature[]> {
  const geometry = JSON.stringify({ x: lng, y: lat, spatialReference: { wkid: 4326 } })
  const params = new URLSearchParams({
    geometry,
    geometryType: 'esriGeometryPoint',
    distance:     '50',
    units:        'esriSRUnit_StatuteMile',
    spatialRel:   'esriSpatialRelIntersects',
    inSR:         '4326',
    outFields:    'IncidentId,OutageType,Cause,ImpactedCustomers,County,StartDate,EstimatedRestoreDate',
    returnGeometry: 'false',
    returnCentroid: 'true',
    outSR:          '4326',
    f:              'json',
  })
  const res = await fetch(`${BASE}/query?${params}`)
  if (!res.ok) throw new Error('Nearby query failed')
  const data = await res.json()

  const seen = new Set<string>()
  const features: OutageFeature[] = []

  for (const f of data.features ?? []) {
    const id = String(f.attributes.IncidentId)
    if (seen.has(id)) continue
    seen.add(id)
    features.push({
      type: 'Feature',
      properties: {
        IncidentId:            String(f.attributes.IncidentId),
        OutageType:            f.attributes.OutageType,
        Cause:                 f.attributes.Cause ?? null,
        ImpactedCustomers:     f.attributes.ImpactedCustomers ?? null,
        County:                f.attributes.County ?? null,
        StartDate:             f.attributes.StartDate ?? null,
        EstimatedRestoreDate:  f.attributes.EstimatedRestoreDate ?? null,
      },
      centroid: f.centroid
        ? { x: f.centroid.x, y: f.centroid.y }
        : null,
    })
  }

  return features
}

/** Spatial query — returns outages whose polygon contains the given point */
export async function spatialQuery(lat: number, lng: number): Promise<OutageFeature[]> {
  const geometry = JSON.stringify({ x: lng, y: lat, spatialReference: { wkid: 4326 } })
  const params = new URLSearchParams({
    geometry,
    geometryType: 'esriGeometryPoint',
    spatialRel:   'esriSpatialRelIntersects',
    inSR:         '4326',
    outFields:    'IncidentId,OutageType,Cause,ImpactedCustomers,County,StartDate,EstimatedRestoreDate',
    returnGeometry: 'false',
    returnCentroid: 'true',
    outSR:          '4326',
    f:              'json',
  })
  const res = await fetch(`${BASE}/query?${params}`)
  if (!res.ok) throw new Error('Spatial query failed')
  const data = await res.json()

  const seen = new Set<string>()
  const features: OutageFeature[] = []

  for (const f of data.features ?? []) {
    const id = String(f.attributes.IncidentId)
    if (seen.has(id)) continue
    seen.add(id)
    features.push({
      type: 'Feature',
      properties: {
        IncidentId:            String(f.attributes.IncidentId),
        OutageType:            f.attributes.OutageType,
        Cause:                 f.attributes.Cause ?? null,
        ImpactedCustomers:     f.attributes.ImpactedCustomers ?? null,
        County:                f.attributes.County ?? null,
        StartDate:             f.attributes.StartDate ?? null,
        EstimatedRestoreDate:  f.attributes.EstimatedRestoreDate ?? null,
      },
      centroid: f.centroid
        ? { x: f.centroid.x, y: f.centroid.y }
        : null,
    })
  }

  return features
}
