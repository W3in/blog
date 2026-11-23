<script setup lang="ts">
definePageMeta({ middleware: 'auth' })
const errors = ref<Record<string, string[]>>({})
const { headers } = useAuth()
async function create(article: object) {
  try {
    const created = await $fetch<{ id: number }>('/api/articles', {
      method: 'POST',
      body: { article },
      headers: headers.value
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
    <NuxtLink to="/" class="back-link"><ArrowLeftOutlined /> Tất cả bài viết</NuxtLink>
    <h1 class="page-title">Tạo bài viết</h1>
    <a-card>
      <ArticleForm :errors="errors" submit-label="Đăng bài" cancel-to="/" @submit="create" />
    </a-card>
  </main>
</template>
