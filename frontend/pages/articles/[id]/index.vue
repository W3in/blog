<script setup lang="ts">
// Rails decides what each viewer gets: no names/ids for anonymous comments, can_destroy per comment
type Comment = {
  id: number; body: string; anonymous: boolean
  commenter: string | null // name when it was written
  current_name: string | null // name now (null for anonymous)
  created_at: string; can_destroy: boolean
}
type Article = {
  id: number; title: string; body: string; status: string; user_id: number
  created_at: string; updated_at: string; comments_count: number
  truncated: boolean // guests: body is only the beginning
  user: { id: number; name: string } | null
  comments?: Comment[] // missing for guests
}

const { headers, user } = useAuth()
const id = useRoute().params.id
const { data: article, refresh, error } = await useFetch<Article>(`/api/articles/${id}`, { headers })
if (error.value) {
  throw createError({
    statusCode: error.value.statusCode ?? 500,
    statusMessage: 'Bài viết này không tồn tại.',
    fatal: true
  })
}

const comments = computed(() => article.value?.comments ?? [])
const edited = computed(() => article.value && article.value.updated_at !== article.value.created_at)

// Same rules as ArticlesController. These only hide buttons; Rails still answers 403 to anyone who tries
const isAuthor = computed(() => !!user.value && user.value.id === article.value?.user_id)
const canDestroyArticle = computed(() => isAuthor.value || !!user.value?.admin)

async function destroyArticle() {
  await $fetch(`/api/articles/${id}`, { method: 'DELETE', headers: headers.value })
  await navigateTo('/')
}

// --- Comment box ---
const newComment = reactive({ body: '', anonymous: false })
const commentError = ref('')
const posting = ref(false)

async function addComment() {
  if (!newComment.body.trim() || posting.value) return
  posting.value = true
  commentError.value = ''
  try {
    await $fetch(`/api/articles/${id}/comments`, { method: 'POST', body: { comment: newComment }, headers: headers.value })
    newComment.body = ''
    await refresh() // reload the article so the new comment and the new count show up
  } catch (e: any) {
    if (e.status !== 422) throw e
    commentError.value = e.data?.body ? `Bình luận ${e.data.body.join(', ')}` : 'Không gửi được bình luận'
  } finally {
    posting.value = false
  }
}

async function destroyComment(commentId: number) {
  await $fetch(`/api/articles/${id}/comments/${commentId}`, { method: 'DELETE', headers: headers.value })
  await refresh()
}

// Guests come back to this article after logging in
const loginTo = computed(() => ({ path: '/login', query: { redirect: `/articles/${id}` } }))
</script>

<template>
  <main v-if="article">
    <NuxtLink to="/" class="back-link"><ArrowLeftOutlined /> Tất cả bài viết</NuxtLink>

    <article class="post">
      <header class="post-meta">
        <a-avatar :style="{ backgroundColor: avatarColor(article.user?.name) }">{{ initial(article.user?.name) }}</a-avatar>
        <div>
          <div class="post-author">{{ article.user?.name ?? 'Không rõ' }}</div>
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
        <span class="pill"><MessageOutlined /> {{ article.comments_count }} bình luận</span>
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
      <!-- No form labels or "*": one box with the options underneath, like Reddit's comment box -->
      <div class="composer">
        <a-textarea
          v-model:value="newComment.body"
          :bordered="false"
          :auto-size="{ minRows: 2, maxRows: 12 }"
          placeholder="Viết bình luận..."
          aria-label="Nội dung bình luận"
          @keydown.ctrl.enter="addComment"
        />
        <div class="composer-bar">
          <a-checkbox v-model:checked="newComment.anonymous">Ẩn danh</a-checkbox>
          <span class="muted small composer-as">
            {{ newComment.anonymous ? 'Không ai thấy tên bạn' : `Bình luận với tên ${user.name}` }}
          </span>
          <a-button type="primary" shape="round" :disabled="!newComment.body.trim()" :loading="posting" @click="addComment">Bình luận</a-button>
        </div>
      </div>
      <p v-if="commentError" class="composer-error">{{ commentError }}</p>

      <h2 class="comments-title">Bình luận ({{ comments.length }})</h2>
      <p v-if="!comments.length" class="muted">Chưa có bình luận nào. Hãy là người đầu tiên!</p>

      <div v-for="c in comments" :key="c.id" class="comment">
        <a-avatar v-if="c.anonymous" size="small" class="comment-avatar" :style="{ backgroundColor: '#8c8c8c' }">
          <template #icon><UserOutlined /></template>
        </a-avatar>
        <a-avatar v-else size="small" class="comment-avatar" :style="{ backgroundColor: avatarColor(c.commenter) }">{{ initial(c.commenter) }}</a-avatar>

        <div class="comment-main">
          <div class="small">
            <!-- Renamed since: keep the old name, show the current one on hover / tap / keyboard focus -->
            <a-tooltip v-if="!c.anonymous && c.current_name && c.current_name !== c.commenter"
              :title="`Hiện tên là ${c.current_name}`" :trigger="['hover', 'click', 'focus']">
              <span class="comment-author renamed" tabindex="0">{{ c.commenter }}</span>
            </a-tooltip>
            <span v-else class="comment-author" :class="{ anonymous: c.anonymous }">{{ c.anonymous ? 'Ẩn danh' : c.commenter }}</span>
            <span class="muted"> • {{ formatDateTime(c.created_at) }}</span>
          </div>
          <p class="comment-body">{{ c.body }}</p>
          <a-popconfirm v-if="c.can_destroy" title="Xóa bình luận này?" ok-text="Xóa" cancel-text="Hủy" @confirm="destroyComment(c.id)">
            <a-button type="text" size="small" danger class="comment-delete">Xóa</a-button>
          </a-popconfirm>
        </div>
      </div>
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
  font-weight: 600;
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

/* One rounded box around the textarea and its bottom bar; blue border while typing */
.composer {
  border: 1px solid #d9d9d9;
  border-radius: 12px;
  transition: border-color 0.2s, box-shadow 0.2s;
}

.composer:focus-within {
  border-color: #1677ff;
  box-shadow: 0 0 0 2px rgba(5, 145, 255, 0.1);
}

.composer-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px 12px;
  padding: 8px 12px;
  border-top: 1px solid #f5f5f5;
}

/* Pushes the button to the right */
.composer-as {
  flex: 1;
}

.composer-error {
  margin: 8px 0 0;
  color: #ff4d4f;
}

.comments-title {
  margin: 24px 0 12px;
  font-size: 16px;
  font-weight: 600;
}

/* Avatar column + a thin line under it, like a Reddit thread */
.comment {
  position: relative;
  display: flex;
  gap: 10px;
  padding-bottom: 12px;
}

.comment-avatar {
  flex: none;
}

.comment::before {
  content: '';
  position: absolute;
  top: 30px;
  bottom: 4px;
  left: 11px;
  width: 2px;
  border-radius: 1px;
  background: #f0f0f0;
}

.comment-main {
  flex: 1;
  min-width: 0;
}

.comment-author {
  font-weight: 600;
}

/* Dotted underline + help cursor: tells the reader there is more to see here */
.comment-author.renamed {
  border-bottom: 1px dotted currentColor;
  cursor: help;
}

.comment-author.anonymous {
  font-style: italic;
  color: rgba(0, 0, 0, 0.55);
}

/* Keep the line breaks the writer typed */
.comment-body {
  margin: 2px 0 0;
  white-space: pre-line;
  overflow-wrap: anywhere;
}

.comment-delete {
  margin-left: -8px; /* text button padding: line up with the comment text */
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
