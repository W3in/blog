import type { Ref } from 'vue'

// One comment as Rails sends it (Comment#as_json_for). Anonymous / deleted ones have no writer fields
export type CommentItem = {
  id: number
  parent_id: number | null // the comment it answers; null = top-level
  body: string | null // null when deleted
  deleted: boolean
  anonymous: boolean
  commenter: string | null // name when it was written
  current_name: string | null // name now
  avatar_url: string | null
  created_at: string
  likes_count: number
  liked: boolean // this viewer gave it a heart
  can_destroy: boolean
}

// What the article page shares with every CommentThread (provide / inject)
export type ThreadContext = {
  articleId: string
  childrenOf: Ref<Record<number, CommentItem[]>>
  refresh: () => Promise<void>
}
