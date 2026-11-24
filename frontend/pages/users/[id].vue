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

    <ProfileHeader :name="profile.name" :avatar-url="profile.avatar_url">
      <template #meta>
        <span><CalendarOutlined /> Thành viên từ {{ formatDate(profile.created_at) }}</span>
        <span><FileTextOutlined /> {{ profile.articles.length }} bài viết</span>
      </template>
      <template v-if="isMe" #actions>
        <NuxtLink v-slot="{ href, navigate }" to="/profile" custom>
          <a-button :href="href" @click="navigate"><EditOutlined /> Chỉnh sửa hồ sơ</a-button>
        </NuxtLink>
      </template>
    </ProfileHeader>

    <h2 class="section-title">Bài viết</h2>
    <a-card v-if="!profile.articles.length"><a-empty description="Chưa có bài viết nào" /></a-card>
    <div v-else class="feed">
      <ArticleCard v-for="item in profile.articles" :key="item.id" :item="item" />
    </div>
  </main>
</template>

<style scoped>
.section-title {
  margin: 0 0 12px;
  font-size: 18px;
  font-weight: 600;
}
</style>
