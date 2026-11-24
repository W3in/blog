<script setup lang="ts">
import type { Notice } from '~/composables/useNotifications'

const { data, refresh, markAllRead } = useNotifications()
const route = useRoute()
const open = ref(false)

// Checked when the page opens, on every page change, and every 30 seconds.
// shortcut: polling, not realtime; switch to Action Cable (WebSocket) if 30 s feels too slow
let timer: ReturnType<typeof setInterval> | undefined
onMounted(() => {
  refresh()
  timer = setInterval(refresh, 30_000)
})
onBeforeUnmount(() => clearInterval(timer)) // logged out: stop asking
watch(() => route.path, refresh)

function onOpenChange(value: boolean) {
  open.value = value
  if (value) markAllRead()
}

const describe = (n: Notice) => (n.kind === 'reply' ? 'đã trả lời bình luận của bạn trong' : 'đã bình luận bài viết')

async function go(n: Notice) {
  open.value = false
  // #comment-12: the article page scrolls to that comment and flashes it
  await navigateTo(`/articles/${n.article.id}#comment-${n.comment_id}`)
}
</script>

<template>
  <a-dropdown :open="open" :trigger="['click']" placement="bottomRight" @open-change="onOpenChange">
    <button type="button" class="bell" :aria-label="`Thông báo, ${data.unread_count} chưa đọc`">
      <a-badge :count="data.unread_count" size="small" :offset="[2, -2]">
        <BellOutlined class="bell-icon" />
      </a-badge>
    </button>

    <template #overlay>
      <div class="panel">
        <div class="panel-head">Thông báo</div>
        <div v-if="!data.items.length" class="panel-empty">
          <BellOutlined /> Chưa có thông báo nào
        </div>
        <ul v-else class="list">
          <li v-for="n in data.items" :key="n.id">
            <button type="button" class="item" :class="{ unread: !n.read }" @click="go(n)">
              <UserAvatar v-if="n.actor" :name="n.actor.name" :src="n.actor.avatar_url" :size="36" />
              <a-avatar v-else :size="36" :style="{ backgroundColor: '#bfbfbf' }"><template #icon><UserOutlined /></template></a-avatar>
              <span class="item-text">
                <span>
                  <strong>{{ n.actor?.name ?? 'Ẩn danh' }}</strong> {{ describe(n) }}
                  <strong>{{ n.article.title }}</strong>
                </span>
                <span class="item-excerpt">“{{ n.excerpt }}”</span>
                <span class="item-time">{{ timeAgo(n.created_at) }}</span>
              </span>
              <span v-if="!n.read" class="dot" aria-label="Chưa đọc" />
            </button>
          </li>
        </ul>
      </div>
    </template>
  </a-dropdown>
</template>

<style scoped>
.bell {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: transparent;
  cursor: pointer;
}

.bell:hover {
  background: #f5f5f5;
}

.bell-icon {
  font-size: 18px;
  color: rgba(0, 0, 0, 0.7);
}

/* The dropdown is a plain box: Ant only positions it */
.panel {
  width: 360px;
  max-width: calc(100vw - 24px);
  overflow: hidden;
  border-radius: 12px;
  background: #fff;
  box-shadow: 0 8px 28px rgba(0, 0, 0, 0.14);
}

.panel-head {
  padding: 12px 16px;
  border-bottom: 1px solid #f0f0f0;
  font-weight: 600;
}

.panel-empty {
  padding: 32px 16px;
  color: rgba(0, 0, 0, 0.45);
  text-align: center;
}

.list {
  max-height: 420px;
  margin: 0;
  padding: 4px;
  overflow-y: auto;
  list-style: none;
}

.item {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  width: 100%;
  padding: 10px 12px;
  border: 0;
  border-radius: 8px;
  background: transparent;
  text-align: left;
  font: inherit;
  cursor: pointer;
}

.item:hover {
  background: #f5f5f5;
}

.item.unread {
  background: #f0f7ff;
}

.item-text {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
  font-size: 13px;
  line-height: 1.45;
}

.item-excerpt {
  overflow: hidden;
  color: rgba(0, 0, 0, 0.55);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.item-time {
  color: #1677ff;
  font-size: 12px;
}

.dot {
  flex: none;
  width: 8px;
  height: 8px;
  margin-top: 6px;
  border-radius: 50%;
  background: #1677ff;
}
</style>
