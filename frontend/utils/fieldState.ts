// Rails sends { email: ["has already been taken"] }: turn it into the props a-form-item expects.
// Returns {} when there is no error, so the item's own rules keep control of the red state.
export function fieldState(errors: Record<string, string[]> | undefined, field: string, label: string) {
  const msgs = errors?.[field]
  return msgs?.length
    ? { validateStatus: 'error' as const, help: msgs.map(m => `${label} ${m}`).join(', ') }
    : {}
}
