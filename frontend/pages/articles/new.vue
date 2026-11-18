<script setup lang="ts">
const errors = ref<Record<string, string[]>>({})

async function create(article: object) {
  try {
    const created = await $fetch<{ id: number }>('/api/articles', {
      method: 'POST',
      body: { article }
    })
    await navigateTo(`/articles/${created.id}`)
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data
  }
}
</script>

<template>
  <main>
    <h1>New Article</h1>
    <ArticleForm :errors="errors" submit-label="Create Article" @submit="create" />
  </main>
</template>
