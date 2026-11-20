<script setup lang="ts">
const id = useRoute().params.id
const { headers } = useAuth()
const { data: article, error } = await useFetch<any>(`/api/articles/${id}`, { headers })
const errors = ref<Record<string, string[]>>({})

if (error.value){
  throw createError({
    statusCode: error.value.statusCode ?? 500,
    statusMessage: 'Bài viết này không tồn tại.',
    fatal: true
  })
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
    <h1 class="page-title">Edit Article</h1>
    <a-card>
      <ArticleForm v-if="article" :article="article" :errors="errors" submit-label="Update Article" @submit="update" />
    </a-card>
  </main>
</template>
