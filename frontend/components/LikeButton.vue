<script setup lang="ts">
// Heart + count for an article or a comment. `url` is the like endpoint: POST = heart, DELETE = take it back
const props = defineProps<{ url: string; count: number; liked: boolean; small?: boolean }>()
const { user, headers } = useAuth()
const route = useRoute()

// Local copy so the click shows at once (optimistic); synced again when the page reloads its data
const state = reactive({ count: props.count, liked: props.liked })
watch(() => [props.count, props.liked] as const, ([count, liked]) => Object.assign(state, { count, liked }))
const busy = ref(false)

async function toggle() {
  if (!user.value) return navigateTo({ path: '/login', query: { redirect: route.fullPath } })
  if (busy.value) return
  busy.value = true
  const before = { ...state }
  // Optimistic: change the screen first, then ask Rails; Rails' answer (the real count) wins
  state.liked = !before.liked
  state.count += state.liked ? 1 : -1
  try {
    const res = await $fetch<{ likes_count: number; liked: boolean }>(props.url, {
      method: before.liked ? 'DELETE' : 'POST',
      headers: headers.value
    })
    Object.assign(state, { count: res.likes_count, liked: res.liked })
  } catch {
    Object.assign(state, before) // failed: put it back as it was
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <!-- aria-pressed: screen readers announce it as an on/off button -->
  <button type="button" class="like" :class="{ liked: state.liked, small }" :aria-pressed="state.liked"
    :aria-label="state.liked ? 'Bỏ thích' : 'Thích'" @click="toggle">
    <HeartFilled v-if="state.liked" class="heart" /><HeartOutlined v-else class="heart" />
    <span>{{ state.count }}</span>
  </button>
</template>

<style scoped>
.like {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 12px;
  border: 0;
  border-radius: 999px;
  background: #f0f0f0;
  color: rgba(0, 0, 0, 0.65);
  font-size: 13px;
  cursor: pointer;
  transition: background 0.2s, color 0.2s;
}

.like:hover {
  background: #fff0f6;
  color: #eb2f96;
}

.like.liked {
  background: #fff0f6;
  color: #eb2f96;
}

/* A little pop when it turns red */
.like.liked .heart {
  animation: pop 0.3s ease;
}

@keyframes pop {
  50% {
    transform: scale(1.35);
  }
}

/* Under a comment: no grey pill, just the icon and the number */
.like.small {
  padding: 2px 8px;
  background: transparent;
  font-size: 12px;
}

.like.small:hover,
.like.small.liked {
  background: #fff0f6;
}
</style>
