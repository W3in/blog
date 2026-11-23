const colors = ['#1677ff', '#13c2c2', '#52c41a', '#fa8c16', '#eb2f96', '#722ed1', '#f5222d', '#2f54eb']

// Same name -> same color, on every page and on both server and browser (no random, so no hydration mismatch)
export function avatarColor(name?: string | null) {
  if (!name) return '#bfbfbf'
  let sum = 0
  for (const ch of name) sum += ch.codePointAt(0)!
  return colors[sum % colors.length]
}

// First letter for the avatar, "?" when there is no name
export const initial = (name?: string | null) => name?.trim()[0]?.toUpperCase() ?? '?'
