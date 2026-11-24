<script setup lang="ts">
import type { ArticleItem } from '~/types/article'

// Public page of a user: anyone can open it. Rails decides which articles this viewer may see (visible_to)
type PublicProfile = {
  id: number; name: string; created_at: string; avatar_url: string | null
  articles: ArticleItem[]
}

const { headers, user } = useAuth()
const id = useRoute().params.id
const { data: profile, error } = await useFetch<PublicProfile>(`/api/users/${id}`, { headers })
if (error.value) {
  throw createError({
    statusCode: error.value.statusCode ?? 500,
    statusMessage: 'Không tìm thấy người dùng này.',
    fatal: true
  })
}

const isMe = computed(() => !!user.value && user.value.id === profile.value?.id)
</script>

<template>
  <main v-if="profile">
    <NuxtLink to="/" class="back-link"><ArrowLeftOutlined /> Tất cả bài viết</NuxtLink>

    <section class="hero">
      <UserAvatar :name="profile.name" :src="profile.avatar_url" :size="96" class="hero-avatar" />
      <div class="hero-info">
        <h1 class="hero-name">{{ profile.name }}</h1>
        <div class="muted">Thành viên từ {{ formatDate(profile.created_at) }} • {{ profile.articles.length }} bài viết</div>
      </div>
      <NuxtLink v-if="isMe" v-slot="{ href, navigate }" to="/profile" custom>
        <a-button :href="href" class="hero-edit" @click="navigate"><EditOutlined /> Chỉnh sửa hồ sơ</a-button>
      </NuxtLink>
    </section>

    <h2 class="section-title">Bài viết</h2>
    <a-card v-if="!profile.articles.length"><a-empty description="Chưa có bài viết nào" /></a-card>
    <div v-else class="feed">
      <ArticleCard v-for="item in profile.articles" :key="item.id" :item="item" />
    </div>
  </main>
</template>

<style scoped>
/* Coloured band on top, white card below: the usual "profile header" look */
.hero {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 20px;
  padding: 24px;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  background: linear-gradient(#e6f4ff 0 56px, #fff 56px);
}

.hero-avatar {
  border: 4px solid #fff;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12);
}

.hero-info {
  flex: 1;
  min-width: 0;
  padding-top: 40px; /* below the coloured band */
}

.hero-name {
  margin: 0;
  font-size: 24px;
  font-weight: 600;
  overflow-wrap: anywhere;
}

.hero-edit {
  align-self: flex-end;
}

.section-title {
  margin: 24px 0 12px;
  font-size: 18px;
  font-weight: 600;
}

@media (max-width: 576px) {
  .hero {
    padding: 16px;
  }

  .hero-edit {
    width: 100%;
  }
}
</style>
