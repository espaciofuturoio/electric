declare module 'react' {
  export function useMemo<T>(factory: () => T, deps: Array<unknown>): T
}

declare module '@tanstack/react-db' {
  export function useLiveQuery<T>(config: {
    query: unknown
    queryKey?: ReadonlyArray<unknown>
  }): { data?: T }
}
