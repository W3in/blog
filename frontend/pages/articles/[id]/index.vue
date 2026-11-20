<script setup lang="ts">
type Comment = { id: number; commenter: string; body: string; status: string | null; user_id: number | null }
const { headers, user } = useAuth()
const id = useRoute().params.id
const { data: article, refresh, error } = await useFetch<any>(`/api/articles/${id}`, { headers })
if (error.value) {
  throw createError({
    statusCode: error.value.statusCode ?? 500,
    statusMessage: 'Bài viết này không tồn tại.',
    fatal: true
  })
}

// Same rule as _comment.html.erb: archived comments are hidden
const comments = computed<Comment[]>(() =>
  (article.value?.comments ?? []).filter((c: Comment) => c.status !== 'archived')
)

// Same rules as the Rails controllers. These only hide buttons; Rails still answers 403 to anyone who tries.
const isAuthor = computed(() => !!user.value && user.value.id === article.value?.user_id)
const canDestroyArticle = computed(() => isAuthor.value || !!user.value?.admin)
const canDestroyComment = (c: Comment) => !!user.value && (c.user_id === user.value.id || user.value.admin)

const statusColor: Record<string, string> = { public: 'green', private: 'orange', archived: 'default' }

// Confirmation now comes from <a-popconfirm>, so these run only after the user said yes
async function destroyArticle() {
  await $fetch(`/api/articles/${id}`, { method: 'DELETE' , headers: headers.value })
  await navigateTo('/')
}

// No commenter field: Rails takes the name from the logged-in account
const newComment = reactive({ body: '', status: 'public' })
const commentErrors = ref<Record<string, string[]>>({})

async function addComment() {
  try {
    await $fetch(`/api/articles/${id}/comments`, { method: 'POST', body: { comment: newComment }, headers: headers.value })
    newComment.body = ''
    commentErrors.value = {}
    await refresh() // reload article so the new comment shows up
  } catch (e: any) {
    if (e.status !== 422) throw e
    commentErrors.value = e.data
  }
}

async function destroyComment(commentId: number) {
  await $fetch(`/api/articles/${id}/comments/${commentId}`, { method: 'DELETE', headers: headers.value })
  await refresh()
}

const statusOptions = ['public', 'private', 'archived'].map(s => ({ value: s, label: s }))
</script>

<template>
  <main v-if="article">
    <NuxtLink to="/" class="back-link"><ArrowLeftOutlined /> Tất cả bài viết</NuxtLink>

    <a-card>
      <h1 class="page-title">{{ article.title }}</h1>
      <div class="meta">
        <a-tag v-if="article.status" :color="statusColor[article.status]">{{ article.status }}</a-tag>
        <span><UserOutlined /> {{ article.user?.name ?? 'Không rõ' }}</span>
        <span><CalendarOutlined /> {{ formatDate(article.created_at) }}</span>
        <!-- Rails sets both timestamps to the same value on create, so different means edited -->
        <span v-if="article.updated_at !== article.created_at">
          <EditOutlined /> Sửa lần cuối {{ formatDateTime(article.updated_at) }}
        </span>
      </div>

      <p class="article-body">{{ article.body }}</p>

      <a-space v-if="isAuthor || canDestroyArticle" wrap>
        <NuxtLink v-if="isAuthor" v-slot="{ href, navigate }" :to="`/articles/${id}/edit`" custom>
          <a-button :href="href" @click="navigate"><EditOutlined /> Edit</a-button>
        </NuxtLink>
        <a-popconfirm v-if="canDestroyArticle" title="Xóa bài viết này?" ok-text="Xóa" cancel-text="Hủy" @confirm="destroyArticle">
          <a-button danger><DeleteOutlined /> Destroy</a-button>
        </a-popconfirm>
      </a-space>
    </a-card>

    <h2 class="section-title">Comments ({{ comments.length }})</h2>
    <!-- vertical list items already have their own side padding, so the card adds none -->
    <a-card :body-style="{ padding: comments.length ? '0' : '24px' }">
      <a-empty v-if="!comments.length" description="Chưa có comment nào" />
      <a-list v-else item-layout="vertical" :data-source="comments">
        <template #renderItem="{ item }">
          <a-list-item>
            <a-list-item-meta>
              <template #avatar>
                <a-avatar :style="{ backgroundColor: '#87d068' }">{{ (item.commenter || '?')[0].toUpperCase() }}</a-avatar>
              </template>
              <template #title>
                <span class="commenter">{{ item.commenter || 'Ẩn danh' }}</span>
              </template>
              <template #description>
                <span class="comment-body">{{ item.body }}</span>
              </template>
            </a-list-item-meta>
            <!-- v-if on a slot: no Destroy button at all for people who may not delete this comment -->
            <template v-if="canDestroyComment(item)" #actions>
              <a-popconfirm title="Xóa comment này?" ok-text="Xóa" cancel-text="Hủy" @confirm="destroyComment(item.id)">
                <a-button type="text" danger size="small">Destroy</a-button>
              </a-popconfirm>
            </template>
          </a-list-item>
        </template>
      </a-list>
    </a-card>

    <h2 class="section-title">Add a comment</h2>
    <a-card v-if="user">
      <a-form layout="vertical" :model="newComment" @finish="addComment">
        <p class="comment-as">Bình luận với tên <strong>{{ user.name }}</strong></p>
        <a-form-item label="Body" :validate-status="commentErrors.body ? 'error' : ''" :help="commentErrors.body?.join(', ')">
          <a-textarea v-model:value="newComment.body" :rows="3" placeholder="Viết comment..." />
        </a-form-item>
        <a-form-item label="Status" :validate-status="commentErrors.status ? 'error' : ''" :help="commentErrors.status?.join(', ')">
          <!-- fixed id: otherwise a-select makes a different id on server and browser (hydration warning) -->
          <a-select id="comment-status" v-model:value="newComment.status" :options="statusOptions" />
        </a-form-item>
        <a-button type="primary" html-type="submit">Create Comment</a-button>
      </a-form>
    </a-card>
    <!-- Guests: Rails would answer 401 anyway, so show the way in instead of a form that cannot work -->
    <a-card v-else class="login-prompt">
      <p>Đăng nhập để tham gia bình luận.</p>
      <a-space>
        <NuxtLink v-slot="{ href, navigate }" to="/login" custom>
          <a-button type="primary" :href="href" @click="navigate">Đăng nhập</a-button>
        </NuxtLink>
        <NuxtLink v-slot="{ href, navigate }" to="/register" custom>
          <a-button :href="href" @click="navigate">Đăng ký</a-button>
        </NuxtLink>
      </a-space>
    </a-card>
  </main>
</template>

<style scoped>
.meta {
  display: flex;
  flex-wrap: wrap; /* phones: author / date / edited move to a new line instead of overflowing */
  align-items: center;
  gap: 8px 16px;
  margin-bottom: 16px;
  color: rgba(0, 0, 0, 0.45);
}

/* Keep the line breaks the author typed */
.article-body {
  white-space: pre-line;
  font-size: 16px;
  line-height: 1.7;
  margin-bottom: 24px;
}

.section-title {
  margin: 32px 0 12px;
  font-size: 18px;
  font-weight: 600;
}

.comment-as {
  margin: 0 0 16px;
  color: rgba(0, 0, 0, 0.45);
}

.login-prompt {
  text-align: center;
}

.login-prompt p {
  margin-bottom: 12px;
  color: rgba(0, 0, 0, 0.65);
}

.commenter {
  font-weight: 600;
}

.comment-body {
  color: rgba(0, 0, 0, 0.75);
  white-space: pre-line;
}</style>
