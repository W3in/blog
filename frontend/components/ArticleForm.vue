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
</script>

<template>
  <form @submit.prevent="emit('submit', { ...form })">
    <div>
      <label>Title</label><br>
      <input v-model="form.title" type="text">
      <div v-for="m in errors?.title" :key="m">Title {{ m }}</div>
    </div>

    <div>
      <label>Body</label><br>
      <textarea v-model="form.body" />
      <div v-for="m in errors?.body" :key="m">Body {{ m }}</div>
    </div>

    <div>
      <label>Status</label><br>
      <select v-model="form.status">
        <option>public</option>
        <option>private</option>
        <option>archived</option>
      </select>
      <div v-for="m in errors?.status" :key="m">Status {{ m }}</div>
    </div>

    <button type="submit">{{ submitLabel ?? 'Save' }}</button>
  </form>
</template>
