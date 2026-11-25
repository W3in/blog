// One article in a list (home page, a user's page). Rails' Article#card_json: no body, an excerpt instead
export type ArticleItem = {
  id: number; title: string; status: string
  excerpt: string; cover_image: string | null; comments_count: number; likes_count: number
  created_at: string
  user: { id: number; name: string; avatar_url: string | null; deleted: boolean } | null
  slug: string
}
