export type Notice = {
  id: number
  kind: 'comment' | 'reply'
  read: boolean
  created_at: string
  actor: { id: number; name: string; avatar_url: string | null } | null // null: anonymous comment
  article: { id: number; title: string }
  comment_id: number
  excerpt: string
}

// The bell's data, shared by every component through useState (like useAuth's user)
export function useNotifications() {
  const { user, headers } = useAuth()
  const data = useState<{ unread_count: number; items: Notice[] }>('notifications', () => ({ unread_count: 0, items: [] }))

  async function refresh() {
    if (!user.value) return
    try {
      data.value = await $fetch('/api/notifications', { headers: headers.value })
    } catch {
      // a failed check is not worth an error on screen: the next one (30 s later) tries again
    }
  }

  // Opening the bell counts as reading everything. The list keeps its "unread" dots until the next refresh,
  // so the user still sees which ones are new
  async function markAllRead() {
    if (!data.value.unread_count) return
    data.value.unread_count = 0
    await $fetch('/api/notifications/read', { method: 'POST', headers: headers.value }).catch(() => {})
  }

  return { data, refresh, markAllRead }
}
