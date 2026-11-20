<script setup lang="ts">
type Article = { title: string; body: string; status: string | null }

const props = defineProps<{
  article?: Article
  errors?: Record<string, string[]>
  submitLabel?: string
}>()
const emit = defineEmits<{ submit: [Article] }>()

// Copy so typing in the form does not mutate the parent's data before saving
const form = reactive<Article>({
  title: props.article?.title ?? '',
  body: props.article?.body ?? '',
  status: props.article?.status ?? 'public'
})

const statusOptions = ['public', 'private', 'archived'].map(s => ({ value: s, label: s }))

// Rails sends { title: ["can't be blank"] }: turn it into the props a-form-item expects
function fieldState(field: string, label: string) {
  const msgs = props.errors?.[field]
  return msgs?.length
    ? { validateStatus: 'error' as const, help: msgs.map(m => `${label} ${m}`).join(', ') }
    : {}
}
</script>

<template>
  <a-form layout="vertical" :model="form" @finish="emit('submit', { ...form })">
    <a-form-item label="Title" v-bind="fieldState('title', 'Title')">
      <a-input v-model:value="form.title" placeholder="Tiêu đề bài viết" />
    </a-form-item>

    <a-form-item label="Body" v-bind="fieldState('body', 'Body')">
      <a-textarea v-model:value="form.body" :rows="8" placeholder="Nội dung (ít nhất 10 ký tự)" />
    </a-form-item>

    <a-form-item label="Status" v-bind="fieldState('status', 'Status')">
      <!-- fixed id: otherwise a-select makes a different id on server and browser (hydration warning) -->
      <a-select id="article-status" v-model:value="form.status" :options="statusOptions" />
    </a-form-item>

    <a-button type="primary" html-type="submit">{{ submitLabel ?? 'Save' }}</a-button>
  </a-form>
</template>
