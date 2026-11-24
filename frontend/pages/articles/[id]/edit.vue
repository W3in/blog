<script setup lang="ts">
definePageMeta({ middleware: 'auth' })
const id = useRoute().params.id
const { headers, user } = useAuth()
const { data: article, error } = await useFetch<any>(`/api/articles/${id}`, { headers })
const errors = ref<Record<string, string[]>>({})

if (error.value){
  throw createError({
    statusCode: error.value.statusCode ?? 500,
    // Only a real 404 means "does not exist"; no answer at all (server down) gets the generic message
    statusMessage: error.value.statusCode === 404 ? 'Bài viết này không tồn tại.' : undefined,
    fatal: true
  })
}

if (article.value.user_id !== user.value?.id) {
  throw createError({ statusCode: 403, statusMessage: 'Bạn không phải tác giả bài này.', fatal: true })
}

async function update(changes: object) {
  try {
    await $fetch(`/api/articles/${id}`, { method: 'PATCH', body: { article: changes }, headers: headers.value })
    await navigateTo(`/articles/${id}`)
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data
  }
}
</script>

<template>
  <main>
    <NuxtLink :to="`/articles/${id}`" class="back-link"><ArrowLeftOutlined /> Quay lại bài viết</NuxtLink>
    <h1 class="page-title">Sửa bài viết</h1>
    <a-card>
      <ArticleForm v-if="article" :article="article" :errors="errors" submit-label="Lưu thay đổi" :cancel-to="`/articles/${id}`" @submit="update" />
    </a-card>
  </main>
</template>
