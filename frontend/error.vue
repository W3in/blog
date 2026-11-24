<script setup lang="ts">
import type { NuxtError } from '#app'
import viVN from 'ant-design-vue/es/locale/vi_VN'

// Nuxt shows this page instead of its English one for every error (404, 403, 500...)
const props = defineProps<{ error: NuxtError }>()

const titles: Record<number, string> = {
  403: 'Bạn không có quyền xem trang này',
  404: 'Không tìm thấy trang',
  500: 'Có lỗi xảy ra'
}
const title = computed(() => titles[props.error.statusCode] ?? 'Có lỗi xảy ra')
// Our own createError messages are already Vietnamese; Nuxt's default ones ("Page not found: /x") are not
const detail = computed(() => {
  const msg = props.error.statusMessage
  return msg && !/not found|error/i.test(msg) ? msg : 'Trang bạn tìm có thể đã bị xóa hoặc đường dẫn không đúng.'
})

useHead({ title: `${props.error.statusCode} - ${title.value}` })

// clearError: forget the error, then go to the home page
const goHome = () => clearError({ redirect: '/' })
</script>

<!-- error.vue replaces app.vue entirely, so it needs the same wrappers: AExtractStyle (Ant CSS in the
     server HTML, no unstyled flash) and the Vietnamese locale -->
<template>
  <AExtractStyle>
  <a-config-provider :locale="viVN">
  <NuxtLayout>
    <main class="error-page">
      <div class="code">{{ error.statusCode }}</div>
      <h1 class="title">{{ title }}</h1>
      <p class="muted">{{ detail }}</p>
      <a-button type="primary" size="large" @click="goHome"><HomeOutlined /> Về trang chủ</a-button>
    </main>
  </NuxtLayout>
  </a-config-provider>
  </AExtractStyle>
</template>

<style scoped>
.error-page {
  padding-top: 72px;
  text-align: center;
}

.code {
  font-size: 72px;
  font-weight: 800;
  line-height: 1;
  color: #1677ff;
}

.title {
  margin: 12px 0 4px;
  font-size: 22px;
  font-weight: 600;
}

.error-page p {
  margin-bottom: 24px;
}
</style>
