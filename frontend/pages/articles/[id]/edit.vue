<script setup lang="ts">
const id = useRoute().params.id
const { data: article, error } = await useFetch<any>(`/api/articles/${id}`)
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
    await $fetch(`/api/articles/${id}`, { method: 'PATCH', body: { article: changes } })
    await navigateTo(`/articles/${id}`)
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data
  }
}
</script>

<template>
  <main>
    <h1>Edit Article</h1>
    <ArticleForm v-if="article" :article="article" :errors="errors" submit-label="Update Article" @submit="update" />
  </main>
</template>
