<script setup lang="ts">
import type { CommentItem, ThreadContext } from '~/types/comment'

// Rails decides what each viewer gets: no names/ids for anonymous comments, can_destroy and liked per comment
type Article = {
  id: number; title: string; body: string; status: string; user_id: number
  created_at: string; updated_at: string; comments_count: number
  likes_count: number; liked?: boolean // liked: only for members
  truncated: boolean // guests: body is only the beginning
  user: { id: number; name: string; avatar_url: string | null; deleted: boolean } | null
  comments?: CommentItem[] // missing for guests
}

const { headers, user } = useAuth()
const id = useRoute().params.id as string
const { data: article, refresh, error } = await useFetch<Article>(`/api/articles/${id}`, { headers })
if (error.value) {
  throw createError({
    statusCode: error.value.statusCode ?? 500,
    // Only a real 404 means "does not exist"; no answer at all (server down) gets the generic message
    statusMessage: error.value.statusCode === 404 ? 'Bài viết này không tồn tại.' : undefined,
    fatal: true
  })
}

const comments = computed(() => article.value?.comments ?? [])

// Rails sends one flat list (oldest first) with parent_id; group it into "replies of comment X"
const childrenOf = computed(() => {
  const map: Record<number, CommentItem[]> = {}
  for (const c of comments.value) {
    if (c.parent_id) (map[c.parent_id] ??= []).push(c) // ??=: create the list the first time
  }
  return map
})
const topLevel = computed(() => comments.value.filter(c => !c.parent_id))

// Every CommentThread, at any depth, reads this with inject('thread')
provide<ThreadContext>('thread', { articleId: id, childrenOf, refresh: () => refresh() })
const edited = computed(() => article.value && article.value.updated_at !== article.value.created_at)

// Same rules as ArticlesController. These only hide buttons; Rails still answers 403 to anyone who tries
const isAuthor = computed(() => !!user.value && user.value.id === article.value?.user_id)
const canDestroyArticle = computed(() => isAuthor.value || !!user.value?.admin)

async function destroyArticle() {
  await $fetch(`/api/articles/${id}`, { method: 'DELETE', headers: headers.value })
  await navigateTo('/')
}

// Guests come back to this article after logging in
const loginTo = computed(() => ({ path: '/login', query: { redirect: `/articles/${id}` } }))
</script>

<template>
  <main v-if="article">
    <NuxtLink to="/" class="back-link"><ArrowLeftOutlined /> Tất cả bài viết</NuxtLink>

    <article class="post">
      <header class="post-meta">
        <UserAvatar :name="article.user?.name" :src="article.user?.avatar_url" />
        <div>
          <!-- A deleted account has no page, so its name ("[đã xóa]") is plain text -->
          <NuxtLink v-if="article.user && !article.user.deleted" :to="`/users/${article.user.id}`" class="post-author">{{ article.user.name }}</NuxtLink>
          <div v-else class="post-author">{{ article.user?.name ?? 'Không rõ' }}</div>
          <div class="muted small">
            {{ formatDate(article.created_at) }}
            <!-- Rails sets both timestamps to the same value on create, so different means edited -->
            <span v-if="edited"> • đã sửa {{ formatDateTime(article.updated_at) }}</span>
          </div>
        </div>
        <a-tag v-if="article.status !== 'public'" :color="statusColor[article.status]" class="post-tag">{{ statusLabel[article.status] }}</a-tag>
      </header>

      <h1 class="post-title">{{ article.title }}</h1>

      <!-- v-html is safe here: Rails strips every tag/attribute outside a short safe list before saving -->
      <!-- eslint-disable-next-line vue/no-v-html -->
      <div class="rich-content post-body" :class="{ faded: article.truncated }" v-html="article.body" />

      <footer class="post-actions">
        <a-space :size="8">
          <!-- Guests see the count; clicking sends them to log in (LikeButton) -->
          <LikeButton :url="`/api/articles/${id}/like`" :count="article.likes_count" :liked="!!article.liked" />
          <span class="pill"><MessageOutlined /> {{ article.comments_count }} bình luận</span>
        </a-space>
        <a-space v-if="isAuthor || canDestroyArticle" :size="4">
          <NuxtLink v-if="isAuthor" v-slot="{ href, navigate }" :to="`/articles/${id}/edit`" custom>
            <a-button type="text" :href="href" @click="navigate"><EditOutlined /> Sửa</a-button>
          </NuxtLink>
          <a-popconfirm v-if="canDestroyArticle" title="Xóa bài viết này?" ok-text="Xóa" cancel-text="Hủy" @confirm="destroyArticle">
            <a-button type="text" danger><DeleteOutlined /> Xóa</a-button>
          </a-popconfirm>
        </a-space>
      </footer>
    </article>

    <!-- Guests: Rails sent only the beginning and no comments, so offer the way in -->
    <section v-if="!user" class="gate">
      <div class="gate-icon"><LockOutlined /></div>
      <h2 class="gate-title">{{ article.truncated ? 'Đăng nhập để đọc tiếp' : 'Tham gia thảo luận' }}</h2>
      <p class="muted">
        {{ article.truncated ? 'Bạn đang xem phần đầu bài viết.' : '' }}
        Thành viên đọc được toàn bộ bài và {{ article.comments_count }} bình luận.
      </p>
      <a-space>
        <NuxtLink v-slot="{ href, navigate }" :to="loginTo" custom>
          <a-button type="primary" :href="href" @click="navigate">Đăng nhập</a-button>
        </NuxtLink>
        <NuxtLink v-slot="{ href, navigate }" to="/register" custom>
          <a-button :href="href" @click="navigate">Tạo tài khoản</a-button>
        </NuxtLink>
      </a-space>
    </section>

    <section v-else class="comments">
      <CommentComposer :article-id="id" @posted="refresh" />

      <h2 class="comments-title">Bình luận ({{ comments.length }})</h2>
      <p v-if="!comments.length" class="muted">Chưa có bình luận nào. Hãy là người đầu tiên!</p>

      <!-- Only top-level comments here; each CommentThread draws its own replies -->
      <CommentThread v-for="c in topLevel" :key="c.id" :comment="c" :depth="0" />
    </section>
  </main>
</template>

<style scoped>
.small {
  font-size: 13px;
}

.post {
  padding: 20px 24px 12px;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  background: #fff;
}

.post-meta {
  display: flex;
  align-items: center;
  gap: 10px;
}

.post-author {
  display: block;
  font-weight: 600;
  color: inherit; /* a link to the author's page, but it reads as a name */
  text-decoration: none;
}

a.post-author:hover {
  text-decoration: underline;
}

/* Tag pushed to the right end of the author row */
.post-tag {
  margin: 0 0 0 auto;
}

.post-title {
  margin: 16px 0 12px;
  font-size: 26px;
  font-weight: 700;
  line-height: 1.3;
}

/* Guests: the cut-off text fades out instead of stopping mid-sentence */
.post-body.faded {
  max-height: 360px;
  overflow: hidden;
  -webkit-mask-image: linear-gradient(to bottom, #000 55%, transparent);
  mask-image: linear-gradient(to bottom, #000 55%, transparent);
}

.post-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-top: 8px;
  padding-top: 12px;
  border-top: 1px solid #f0f0f0;
}

.gate {
  margin-top: 16px;
  padding: 28px 24px;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  background: #fff;
  text-align: center;
}

.gate-icon {
  width: 48px;
  height: 48px;
  margin: 0 auto 8px;
  border-radius: 50%;
  background: #e6f4ff;
  color: #1677ff;
  font-size: 22px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.gate-title {
  margin: 0 0 4px;
  font-size: 18px;
  font-weight: 600;
}

.comments {
  margin-top: 16px;
  padding: 20px 24px;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  background: #fff;
}

.comments-title {
  margin: 24px 0 4px;
  font-size: 16px;
  font-weight: 600;
}

@media (max-width: 576px) {
  .post,
  .comments {
    padding: 16px;
  }

  .post-title {
    font-size: 22px;
  }
}
</style>
