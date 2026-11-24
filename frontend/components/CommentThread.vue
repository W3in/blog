<script setup lang="ts">
import type { CommentItem, ThreadContext } from '~/types/comment'

// One comment and, below it, its replies, each drawn by this same component (recursion), Reddit-style
const props = defineProps<{ comment: CommentItem; depth: number }>()

// Given by the article page with provide('thread', ...): no need to pass it down through every level
const thread = inject<ThreadContext>('thread')!
const { headers, user } = useAuth()
const route = useRoute()
// Opened from a notification (/articles/5#comment-12). Not CSS :target: Vue Router changes the URL with
// history.pushState, which does not update :target, so we compare the hash ourselves
const highlighted = computed(() => route.hash === `#comment-${props.comment.id}`)

const children = computed(() => thread.childrenOf.value[props.comment.id] ?? [])
// All replies under this one, at any depth: shown on the "+ N trả lời" button of a collapsed thread
const countAll = (id: number): number =>
  (thread.childrenOf.value[id] ?? []).reduce((sum, c) => sum + 1 + countAll(c.id), 0)

const collapsed = ref(false)
const replying = ref(false)
// Reply box starts with "@Name " of the person answered (nothing for anonymous: their name is hidden)
const replyPrefix = computed(() =>
  props.comment.anonymous ? '' : `@${props.comment.current_name ?? props.comment.commenter} `)

const likeUrl = computed(() => `/api/articles/${thread.articleId}/comments/${props.comment.id}/like`)

async function destroy() {
  await $fetch(`/api/articles/${thread.articleId}/comments/${props.comment.id}`, { method: 'DELETE', headers: headers.value })
  await thread.refresh()
}

async function onPosted() {
  replying.value = false
  await thread.refresh()
}
</script>

<template>
  <!-- id: notifications link to /articles/5#comment-12 and the router scrolls to it -->
  <div :id="`comment-${comment.id}`" class="thread" :class="{ highlighted }">
    <div class="comment">
      <a-avatar v-if="comment.anonymous || comment.deleted" size="small" class="comment-avatar" :style="{ backgroundColor: '#bfbfbf' }">
        <template #icon><UserOutlined /></template>
      </a-avatar>
      <UserAvatar v-else :name="comment.commenter" :src="comment.avatar_url" size="small" class="comment-avatar" />

      <div class="comment-main">
        <!-- comment-box: just this comment (not its replies), the part that flashes when linked to -->
        <div class="comment-box">
        <div class="comment-head">
          <span v-if="comment.deleted" class="comment-author muted-name">[đã xóa]</span>
          <!-- Renamed since: keep the old name, show the current one on hover / tap / keyboard focus -->
          <a-tooltip v-else-if="!comment.anonymous && comment.current_name && comment.current_name !== comment.commenter"
            :title="`Hiện tên là ${comment.current_name}`" :trigger="['hover', 'click', 'focus']">
            <span class="comment-author renamed" tabindex="0">{{ comment.commenter }}</span>
          </a-tooltip>
          <span v-else class="comment-author" :class="{ 'muted-name': comment.anonymous }">{{ comment.anonymous ? 'Ẩn danh' : comment.commenter }}</span>
          <span class="comment-time">• {{ formatDateTime(comment.created_at) }}</span>
        </div>

        <p v-if="comment.deleted" class="comment-body removed">Bình luận này đã bị xóa.</p>
        <p v-else class="comment-body">{{ comment.body }}</p>

        <div class="comment-actions">
          <template v-if="!comment.deleted">
            <LikeButton :url="likeUrl" :count="comment.likes_count" :liked="comment.liked" small />
            <button v-if="user" type="button" class="action" @click="replying = !replying"><MessageOutlined /> Trả lời</button>
            <a-popconfirm v-if="comment.can_destroy" title="Xóa bình luận này?" ok-text="Xóa" cancel-text="Hủy" @confirm="destroy">
              <button type="button" class="action danger"><DeleteOutlined /> Xóa</button>
            </a-popconfirm>
          </template>
          <button v-if="children.length && collapsed" type="button" class="action expand" @click="collapsed = false">
            <PlusCircleOutlined /> {{ countAll(comment.id) }} trả lời
          </button>
        </div>
        </div>

        <CommentComposer v-if="replying" class="reply-box" :article-id="thread.articleId" :parent-id="comment.id"
          :initial="replyPrefix" @posted="onPosted" @cancel="replying = false" />

        <!-- Each level moves right under the avatar column; from depth 3 on it stops moving, or phones run out of width -->
        <div v-if="children.length && !collapsed" class="replies" :class="{ flat: depth >= 3 }">
          <CommentThread v-for="child in children" :key="child.id" :comment="child" :depth="depth + 1" />
        </div>
      </div>

      <!-- The vertical line under the avatar is a button, like on Reddit: click it to fold the replies -->
      <button v-if="children.length && !collapsed" type="button" class="thread-line" aria-label="Thu gọn các trả lời" @click="collapsed = true" />
    </div>
  </div>
</template>

<style scoped>
.comment {
  position: relative;
  display: flex;
  gap: 10px;
  padding-top: 10px;
}

.comment-avatar {
  flex: none;
}

.comment-main {
  flex: 1;
  min-width: 0;
}

.comment-head {
  font-size: 13px;
}

.comment-author {
  font-weight: 600;
}

/* Dotted underline + help cursor: tells the reader there is more to see here */
.comment-author.renamed {
  border-bottom: 1px dotted currentColor;
  cursor: help;
}

.muted-name {
  font-style: italic;
  color: rgba(0, 0, 0, 0.5);
}

.comment-time {
  margin-left: 4px;
  color: rgba(0, 0, 0, 0.45);
}

/* Keep the line breaks the writer typed */
.comment-body {
  margin: 2px 0 0;
  white-space: pre-line;
  overflow-wrap: anywhere;
}

.comment-body.removed {
  font-style: italic;
  color: rgba(0, 0, 0, 0.45);
}

.comment-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 2px;
  margin: 2px 0 0 -8px; /* line the first button's icon up with the text */
}

.action {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: rgba(0, 0, 0, 0.55);
  font-size: 12px;
  cursor: pointer;
}

.action:hover {
  background: #f5f5f5;
  color: rgba(0, 0, 0, 0.85);
}

.action.danger:hover {
  background: #fff1f0;
  color: #cf1322;
}

.action.expand {
  color: #1677ff;
}

.reply-box {
  margin-top: 6px;
}

.replies.flat {
  margin-left: -34px; /* undo the avatar-column shift: 24px avatar + 10px gap */
}

/* Clickable strip under the avatar; only its middle 2px is drawn as the line */
.thread-line {
  position: absolute;
  top: 40px;
  bottom: 0;
  left: 6px;
  width: 12px;
  padding: 0;
  border: 0;
  background: linear-gradient(to right, transparent 5px, #e8e8e8 5px 7px, transparent 7px);
  cursor: pointer;
}

.thread-line:hover,
.thread-line:focus-visible {
  background: linear-gradient(to right, transparent 5px, #1677ff 5px 7px, transparent 7px);
}

/* Negative margin + same padding: room for the flash background without moving the text */
.comment-box {
  margin: -4px -8px;
  padding: 4px 8px;
  border-radius: 8px;
}

/* Opened from a notification (#comment-12): flash a yellow background on that comment */
.thread.highlighted > .comment > .comment-main > .comment-box {
  animation: flash 2.5s ease;
}

@keyframes flash {
  0%,
  40% {
    background: #fff7d6;
  }
}
</style>
