<script setup lang="ts">
import type { ArticleItem } from '~/types/article'

type ArticlePage = { items: ArticleItem[]; total: number; page: number; per_page: number }

const { headers } = useAuth()
const route = useRoute()
const page = computed(() => Number(route.query.page) || 1)
const q = computed(() => String(route.query.q ?? ''))
const search = ref(q.value)
watch(q, value => { search.value = value }) 

function runSearch(value: string) {
  navigateTo({ query: { q: value.trim() || undefined } })
}

const { data, error, refresh, status } = await useFetch<ArticlePage>('/api/articles', { headers, query: { page, q } })

const emptyText = computed(() => {
  if (q.value) return 'Không có bài nào khớp. Thử từ khác xem sao.'
  if (data.value?.total) return 'Trang này không còn bài nào.'
  return 'Chưa có bài viết nào'
})

async function goPage(p: number) {
  await navigateTo({ query: { ...route.query, page: p } })
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

</script>

<template>
  <main>
    <div class="list-head">
      <h1 class="page-title">{{ q ? 'Kết quả tìm kiếm' : 'Bài viết mới' }}</h1>
      <a-input-search v-model:value="search" placeholder="Tìm theo tiêu đề" allow-clear enter-button
        aria-label="Tìm bài viết theo tiêu đề" class="search" @search="runSearch" />
    </div>

    <a-alert v-if="error" type="error" show-icon message="Không tải được danh sách bài viết"
      description="Máy chủ đang tạm ngừng hoặc mạng bị gián đoạn. Hãy thử lại sau ít phút.">
      <template #action>
        <a-button size="small" :loading="status === 'pending'" @click="refresh()"><ReloadOutlined /> Thử lại</a-button>
      </template>
    </a-alert>

    <template v-else-if="data">
        <p v-if="q" class="muted">Tìm thấy {{ data.total }} bài có tiêu đề chứa “{{ q }}”</p>
        <a-card v-if="!data.items.length"><a-empty :description="emptyText" /></a-card>
        <template v-else>
          <div class="feed">
            <ArticleCard v-for="item in data.items" :key="item.id" :item="item" />
          </div>
          <a-pagination :current="page" :total="data.total" :page-size="data.per_page" :show-size-changer="false"
            hide-on-single-page class="pager" @change="goPage" />
        </template>
    </template>
  </main>
</template>


<style scoped>
.pager {
  margin-top: 20px;
  text-align: center;
}

.list-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 16px;
}

.list-head .page-title {
  margin: 0;
}

.search {
  flex: 1 1 240px;
  max-width: 360px;
}

</style>