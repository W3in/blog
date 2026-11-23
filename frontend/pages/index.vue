<script setup lang="ts">
// The list has no body: Rails sends a plain-text excerpt and the first image instead
type ArticleItem = {
  id: number; title: string; status: string
  excerpt: string; cover_image: string | null; comments_count: number
  created_at: string
  user: { id: number; name: string } | null
}
const { headers } = useAuth()
const { data: articles, error } = await useFetch<ArticleItem[]>('/api/articles', { headers })
</script>

<template>
  <main>
    <h1 class="page-title">Bài viết mới</h1>
    <a-alert v-if="error" type="error" show-icon :message="`Không tải được bài viết: ${error.message}`" />
    <a-card v-else-if="!articles?.length"><a-empty description="Chưa có bài viết nào" /></a-card>

    <div v-else class="feed">
      <!-- The whole card is one link, like a Reddit post in the feed -->
      <NuxtLink v-for="item in articles" :key="item.id" :to="`/articles/${item.id}`" class="post-card">
        <div class="card-main">
          <div class="card-meta">
            <a-avatar size="small" :style="{ backgroundColor: avatarColor(item.user?.name) }">{{ initial(item.user?.name) }}</a-avatar>
            <span class="card-author">{{ item.user?.name ?? 'Không rõ' }}</span>
            <span class="muted">• {{ formatDate(item.created_at) }}</span>
            <!-- Only members/authors/admins get non-public articles: tag them so they know who else can see them -->
            <a-tag v-if="item.status !== 'public'" :color="statusColor[item.status]" class="status-tag">{{ statusLabel[item.status] }}</a-tag>
          </div>
          <h2 class="card-title">{{ item.title }}</h2>
          <p v-if="item.excerpt" class="card-excerpt">{{ item.excerpt }}</p>
          <span class="pill"><MessageOutlined /> {{ item.comments_count }} bình luận</span>
        </div>
        <!-- alt="": decoration only, the title already says what the post is -->
        <img v-if="item.cover_image" :src="item.cover_image" alt="" class="card-thumb" loading="lazy">
      </NuxtLink>
    </div>
  </main>
</template>

<style scoped>
.feed {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.post-card {
  display: flex;
  gap: 16px;
  padding: 16px 20px;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  background: #fff;
  color: inherit;
  text-decoration: none;
  transition: border-color 0.2s, box-shadow 0.2s;
}

.post-card:hover,
.post-card:focus-visible {
  border-color: #d9d9d9;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.06);
}

/* min-width: 0 lets long titles wrap instead of pushing the thumbnail out of the card */
.card-main {
  flex: 1;
  min-width: 0;
}

.card-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px;
  font-size: 13px;
}

.card-author {
  font-weight: 600;
}

.status-tag {
  margin: 0;
}

.card-title {
  margin: 8px 0 4px;
  font-size: 18px;
  font-weight: 600;
  line-height: 1.4;
  color: rgba(0, 0, 0, 0.88);
}

/* At most 3 lines of the excerpt */
.card-excerpt {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  margin: 0 0 12px;
  color: rgba(0, 0, 0, 0.65);
}

.card-thumb {
  flex: none;
  width: 120px;
  height: 90px;
  object-fit: cover; /* crop to fill the box instead of stretching */
  border-radius: 8px;
  background: #f5f5f5;
}

@media (max-width: 576px) {
  .post-card {
    padding: 14px 16px;
  }

  .card-thumb {
    width: 80px;
    height: 64px;
  }
}
</style>
