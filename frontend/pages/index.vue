<script setup lang="ts">
type Article = { id: number; title: string; body: string; status: string | null }

const { data: articles, error } = await useFetch<Article[]>('/api/articles')
</script>

<template>
  <main>
    <h1>Articles</h1>
    <p v-if="error">Không tải được bài viết: {{ error.message }}</p>
    <p v-else-if="articles?.length === 0">Chưa có bài viết nào.</p>
    <ul v-else>
      <li v-for="article in articles" :key="article.id">
        <nuxt-link :to="`/articles/${article.id}`">
          <h2>{{ article.title }}</h2>
        </nuxt-link>
        <p>{{ article.body }}</p>
      </li>
    </ul>
    <NuxtLink to="/articles/new">New Article</NuxtLink>
  </main>
</template>
