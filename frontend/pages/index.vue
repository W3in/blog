<script setup lang="ts">
import type { ArticleItem } from '~/types/article'

// The list has no body: Rails sends a plain-text excerpt and the first image instead
const { headers } = useAuth()
const { data: articles, error } = await useFetch<ArticleItem[]>('/api/articles', { headers })
</script>

<template>
  <main>
    <h1 class="page-title">Bài viết mới</h1>
    <a-alert v-if="error" type="error" show-icon :message="`Không tải được bài viết: ${error.message}`" />
    <a-card v-else-if="!articles?.length"><a-empty description="Chưa có bài viết nào" /></a-card>

    <div v-else class="feed">
      <ArticleCard v-for="item in articles" :key="item.id" :item="item" />
    </div>
  </main>
</template>
