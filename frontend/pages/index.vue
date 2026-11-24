<script setup lang="ts">
import type { ArticleItem } from '~/types/article'

// The list has no body: Rails sends a plain-text excerpt and the first image instead
const { headers } = useAuth()
const { data: articles, error, refresh, status } = await useFetch<ArticleItem[]>('/api/articles', { headers })
</script>

<template>
  <main>
    <h1 class="page-title">Bài viết mới</h1>
    <!-- No raw "Failed to fetch": say what it means for the reader and let them try again -->
    <a-alert v-if="error" type="error" show-icon message="Không tải được danh sách bài viết"
      description="Máy chủ đang tạm ngừng hoặc mạng bị gián đoạn. Hãy thử lại sau ít phút.">
      <template #action>
        <a-button size="small" :loading="status === 'pending'" @click="refresh()"><ReloadOutlined /> Thử lại</a-button>
      </template>
    </a-alert>
    <a-card v-else-if="!articles?.length"><a-empty description="Chưa có bài viết nào" /></a-card>

    <div v-else class="feed">
      <ArticleCard v-for="item in articles" :key="item.id" :item="item" />
    </div>
  </main>
</template>
