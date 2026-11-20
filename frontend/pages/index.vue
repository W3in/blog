<script setup lang="ts">
type Article = {
  id: number; title: string; body: string; status: string | null
  created_at: string; updated_at: string
  user: { id: number; name: string } | null
}
const { headers } = useAuth()
const { data: articles, error } = await useFetch<Article[]>('/api/articles', { headers })
</script>

<template>
  <main>
    <h1 class="page-title">Articles</h1>
    <a-alert v-if="error" type="error" show-icon :message="`Không tải được bài viết: ${error.message}`" />

    <a-card v-else :body-style="{ padding: '0 24px' }">
      <a-list item-layout="horizontal" :data-source="articles ?? []">
        <template #renderItem="{ item }">
          <a-list-item>
            <a-list-item-meta>
              <template #description>
                <div class="body-preview">{{ item.body }}</div>
                <div class="item-meta">
                  <span><UserOutlined /> {{ item.user?.name ?? 'Không rõ' }}</span>
                  <span><CalendarOutlined /> {{ formatDate(item.created_at) }}</span>
                </div>
              </template>
              <template #title>
                <NuxtLink :to="`/articles/${item.id}`" class="title-link">{{ item.title }}</NuxtLink>
              </template>
              <template #avatar>
                <a-avatar :style="{ backgroundColor: '#1677ff' }">{{ item.title[0]?.toUpperCase() }}</a-avatar>
              </template>
            </a-list-item-meta>
          </a-list-item>
        </template>
      </a-list>
    </a-card>
  </main>
</template>

<style scoped>
/* Title line as tall as the 32px avatar, so the title text sits on the avatar's middle.
   Set on our own link: a rule on .ant-list-item-meta-title loses to Ant Design's more specific CSS. */
.title-link {
  display: inline-block;
  line-height: 32px;
  font-size: 16px;
}

/* Long article bodies: show at most 2 lines in the list */
.body-preview {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

/* Author + date under the preview: smaller and lighter than the body text */
.item-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 16px;
  margin-top: 8px;
  font-size: 12px;
  color: rgba(0, 0, 0, 0.45);
}

/* Phones: give the text the full width */
@media (max-width: 576px) {
  :deep(.ant-list-item-meta-avatar) {
    display: none;
  }
}
</style>
