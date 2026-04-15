export const CAUSE_LABELS: Record<string, string> = {
  'EMERG REPAIRS':      'Emergency repairs underway',
  'TREE CONTACT':       'Tree contact with power line',
  'PATROLLING':         'Crew is patrolling to locate the fault',
  'PLNND SHUTDOWN':     'Planned shutdown',
  'DAMGE UG CABLE':     'Damaged underground cable',
  'REPLCE TXFMR':       'Replacing transformer',
  'REPLCE SRVC':        'Replacing service line',
  'BRKN UG EQUIPMNT':   'Broken underground equipment',
  'BRKN POLE EQUIPMNT': 'Broken pole equipment',
  'POLE FIRE':          'Pole fire',
  'Awaiting Investigation': 'Awaiting investigation',
}

export function getCauseLabel(cause: string | null): string {
  if (!cause) return 'Outage cause currently unknown'
  return CAUSE_LABELS[cause] ?? cause
}
