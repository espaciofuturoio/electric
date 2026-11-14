import { useMemo } from 'react'
import { useLiveQuery } from '@tanstack/react-db'
import {
  createEntityIncludesQuery,
  getEntityState,
  normalizeEntityTimelineData,
} from './entity-timeline'
import { buildSections } from './use-chat'
import type { EntityStreamDB } from './entity-stream-db'
import type {
  EntityTimelineData,
  EntityTimelineSection,
  EntityTimelineState,
  IncludesEntity,
  IncludesInboxMessage,
  IncludesRun,
  IncludesWakeMessage,
} from './entity-timeline'

export interface UseChatResult {
  sections: Array<EntityTimelineSection>
  state: EntityTimelineState
  runs: Array<IncludesRun>
  inbox: Array<IncludesInboxMessage>
  wakes: Array<IncludesWakeMessage>
  entities: Array<IncludesEntity>
}

const noopQuery = (_q: any): null => null

// TanStack DB 1.0 derives a live query's identity from its IR, which only names
// collection IDs. A StreamDB's collection IDs come from the stream URL, so a
// re-created db for the same entity reuses them with new objects
// (`SourceCollectionIdReuseError`). The query key carries one token per db
// instance instead, so a new db is a new query.
const dbScopes = new WeakMap<EntityStreamDB, number>()
let lastDbScope = 0
const dbScope = (db: EntityStreamDB): number => {
  let scope = dbScopes.get(db)
  if (scope === undefined) {
    scope = ++lastDbScope
    dbScopes.set(db, scope)
  }
  return scope
}

export function useChat(db: EntityStreamDB | null): UseChatResult {
  const includesQuery = useMemo(
    () => (db ? createEntityIncludesQuery(db) : null),
    [db]
  )

  const { data: timelineRows = [] } = useLiveQuery({
    query: includesQuery ?? noopQuery,
    queryKey: db ? [`electric-agents:useChat`, dbScope(db)] : [],
  })
  const timelineData: EntityTimelineData = normalizeEntityTimelineData(
    (timelineRows as Array<EntityTimelineData>)[0] ?? {
      runs: [],
      inbox: [],
      wakes: [],
      signals: [],
      contextInserted: [],
      contextRemoved: [],
      entities: [],
    }
  )
  const typedRuns = timelineData.runs
  const typedInbox = timelineData.inbox
  const typedWakes = timelineData.wakes
  const typedEntities = timelineData.entities

  const state = useMemo(
    () => getEntityState(typedRuns, typedInbox),
    [typedRuns, typedInbox]
  )

  const sections = useMemo(
    () => buildSections(typedRuns, typedInbox),
    [typedRuns, typedInbox]
  )

  return {
    sections,
    state,
    runs: typedRuns,
    inbox: typedInbox,
    wakes: typedWakes,
    entities: typedEntities,
  }
}
