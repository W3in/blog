<script setup lang="ts">
definePageMeta({ middleware: 'auth' })
const id = String(useRoute().params.id).match(/\d+$/)?.[0]
const { headers, user } = useAuth()
const { data: article, error } = await useFetch<any>(`/api/articles/${id}`, { headers })
const errors = ref<Record<string, string[]>>({})
const saving = ref(false)
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
  if (saving.value) return
  saving.value = true
  try {
    const saved = await $fetch<{ slug: string }>(`/api/articles/${id}`, { method: 'PATCH', body: { article: changes }, headers: headers.value })
    await navigateTo(`/articles/${saved.slug}`)
  } catch (e: any) {
    saving.value = false
    if (e.status !== 422) throw e
    errors.value = e.data
  }
}
</script>

<template>
  <main>
    <NuxtLink :to="`/articles/${article.slug}`" class="back-link"><ArrowLeftOutlined /> Quay lại bài viết</NuxtLink>
    <h1 class="page-title">Sửa bài viết</h1>
    <a-card>
      <ArticleForm v-if="article" :article="article" :errors="errors" :loading="saving" submit-label="Lưu thay đổi" :cancel-to="`/articles/${article.slug}`" @submit="update" />
    </a-card>
  </main>
</template>
