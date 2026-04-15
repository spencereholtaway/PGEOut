/** Arc fill percentage (0–100) based on start → ETA window */
export function arcFillPct(startMs: number, etaMs: number): number {
  const now = Date.now()
  const total = etaMs - startMs
  if (total <= 0) return 100
  const elapsed = now - startMs
  return Math.min(100, Math.max(0, (elapsed / total) * 100))
}

/** Remaining ms until ETA, floored at 0 */
export function remainingMs(etaMs: number): number {
  return Math.max(0, etaMs - Date.now())
}

/** Format a duration in ms as "1d 4h", "2h 30m", or "45m" */
export function formatDuration(ms: number): string {
  if (ms <= 0) return '0m'
  const totalMinutes = Math.floor(ms / 60000)
  const days = Math.floor(totalMinutes / 1440)
  const hours = Math.floor((totalMinutes % 1440) / 60)
  const minutes = totalMinutes % 60

  if (days > 0) return `${days}d ${hours}h`
  if (hours > 0) return `${hours}h ${minutes}m`
  return `${minutes}m`
}
