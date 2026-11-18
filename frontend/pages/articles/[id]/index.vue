<script setup lang="ts">
type Comment = { id: number; commenter: string; body: string; status: string | null }

const id = useRoute().params.id
const { data: article, refresh, error } = await useFetch<any>(`/api/articles/${id}`)
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

async function destroyArticle() {
  if (!confirm('Are you sure?')) return
  await $fetch(`/api/articles/${id}`, { method: 'DELETE' })
  await navigateTo('/')
}

const newComment = reactive({ commenter: '', body: '', status: 'public' })
const commentErrors = ref<Record<string, string[]>>({})

async function addComment() {
  try {
    await $fetch(`/api/articles/${id}/comments`, { method: 'POST', body: { comment: newComment } })
    Object.assign(newComment, { commenter: '', body: '' })
    commentErrors.value = {}
    await refresh() // reload article so the new comment shows up
  } catch (e: any) {
    if (e.status !== 422) throw e
    commentErrors.value = e.data
  }
}

async function destroyComment(commentId: number) {
  if (!confirm('Are you sure?')) return
  await $fetch(`/api/articles/${id}/comments/${commentId}`, { method: 'DELETE' })
  await refresh()
}
</script>

<template>
  <main v-if="article">
    <h1>{{ article.title }}</h1>
    <p>{{ article.body }}</p>

    <ul>
      <li><NuxtLink :to="`/articles/${id}/edit`">Edit</NuxtLink></li>
      <li><a href="#" @click.prevent="destroyArticle">Destroy</a></li>
      <li><NuxtLink to="/">Back</NuxtLink></li>
    </ul>

    <h2>Comments</h2>
    <div v-for="c in comments" :key="c.id">
      <p><strong>Commenter:</strong> {{ c.commenter }}</p>
      <p><strong>Comment:</strong> {{ c.body }}</p>
      <p><a href="#" @click.prevent="destroyComment(c.id)">Destroy Comment</a></p>
    </div>

    <h2>Add a comment:</h2>
    <form @submit.prevent="addComment">
      <p><label>Commenter</label><br><input v-model="newComment.commenter"></p>
      <p><label>Body</label><br><textarea v-model="newComment.body" /></p>
      <p>
        <label>Status</label><br>
        <select v-model="newComment.status">
          <option>public</option><option>private</option><option>archived</option>
        </select>
      </p>
      <div v-for="(msgs, field) in commentErrors" :key="field">{{ field }} {{ msgs.join(', ') }}</div>
      <button type="submit">Create Comment</button>
    </form>
  </main>
</template>
