<script setup lang="ts">
// The comment box: at the top of the comments, and inline under a comment when replying (parentId set)
const props = defineProps<{ articleId: string; parentId?: number; initial?: string }>()
const emit = defineEmits<{ posted: []; cancel: [] }>()

const { user, headers } = useAuth()
const form = reactive({ body: props.initial ?? '', anonymous: false })
const error = ref('')
const posting = ref(false)
const box = ref<HTMLElement>()

// A reply box opens with "@Name " already typed: focus it and put the cursor after the name
onMounted(() => {
  if (!props.parentId) return
  const textarea = box.value?.querySelector('textarea')
  textarea?.focus()
  textarea?.setSelectionRange(form.body.length, form.body.length)
})

async function submit() {
  if (!form.body.trim() || posting.value) return
  posting.value = true
  error.value = ''
  try {
    await $fetch(`/api/articles/${props.articleId}/comments`, {
      method: 'POST',
      body: { comment: { ...form, parent_id: props.parentId } },
      headers: headers.value
    })
    form.body = ''
    emit('posted') // the page reloads the comments
  } catch (e: any) {
    if (e.status !== 422) throw e
    error.value = e.data?.body
      ? `Bình luận ${e.data.body.join(', ')}`
      : e.data?.parent ? 'Bình luận này đã bị xóa, không trả lời được nữa' : 'Không gửi được bình luận'
  } finally {
    posting.value = false
  }
}
</script>

<template>
  <div ref="box" class="composer-wrap">
    <!-- No form labels or "*": one box with the options underneath, like Reddit's comment box -->
    <div class="composer">
      <a-textarea
        v-model:value="form.body"
        :bordered="false"
        :auto-size="{ minRows: parentId ? 1 : 2, maxRows: 12 }"
        :placeholder="parentId ? 'Viết trả lời...' : 'Viết bình luận...'"
        aria-label="Nội dung bình luận"
        @keydown.ctrl.enter="submit"
      />
      <div class="composer-bar">
        <a-checkbox v-model:checked="form.anonymous">Ẩn danh</a-checkbox>
        <span class="composer-as">{{ form.anonymous ? 'Không ai thấy tên bạn' : `Với tên ${user?.name}` }}</span>
        <a-button v-if="parentId" type="text" shape="round" size="small" @click="emit('cancel')">Hủy</a-button>
        <a-button type="primary" shape="round" :size="parentId ? 'small' : 'middle'" :disabled="!form.body.trim()" :loading="posting" @click="submit">
          {{ parentId ? 'Trả lời' : 'Bình luận' }}
        </a-button>
      </div>
    </div>
    <p v-if="error" class="composer-error">{{ error }}</p>
  </div>
</template>

<style scoped>
/* One rounded box around the textarea and its bottom bar; blue border while typing */
.composer {
  border: 1px solid #d9d9d9;
  border-radius: 12px;
  background: #fff;
  transition: border-color 0.2s, box-shadow 0.2s;
}

.composer:focus-within {
  border-color: #1677ff;
  box-shadow: 0 0 0 2px rgba(5, 145, 255, 0.1);
}

.composer-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px 12px;
  padding: 6px 10px;
  border-top: 1px solid #f5f5f5;
}

/* Pushes the buttons to the right */
.composer-as {
  flex: 1;
  color: rgba(0, 0, 0, 0.45);
  font-size: 12px;
}

.composer-error {
  margin: 6px 0 0;
  color: #ff4d4f;
  font-size: 13px;
}
</style>
