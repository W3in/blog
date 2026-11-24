<script setup lang="ts">
type Article = { title: string; body: string; status: string | null }

const props = defineProps<{
  article?: Article
  errors?: Record<string, string[]>
  submitLabel?: string
  cancelTo?: string
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
  <a-form layout="vertical" :model="form" @finish="emit('submit', { ...form })">
    <!-- No labels: the placeholders say what goes where, like Reddit's "Create post" -->
    <a-form-item v-bind="fieldState(errors, 'title', 'Tiêu đề')">
      <a-input v-model:value="form.title" size="large" placeholder="Tiêu đề" :maxlength="300" show-count class="title-input" />
    </a-form-item>

    <a-form-item v-bind="fieldState(errors, 'body', 'Nội dung')">
      <RichEditor v-model="form.body" placeholder="Bạn muốn chia sẻ điều gì? Dùng thanh công cụ để định dạng hoặc chèn ảnh." />
    </a-form-item>

    <div class="form-footer">
      <a-form-item label="Ai được xem" class="status-item" v-bind="fieldState(errors, 'status', 'Status')">
        <!-- fixed id: otherwise a-select makes a different id on server and browser (hydration warning) -->
        <a-select id="article-status" v-model:value="form.status" :options="statusOptions" />
      </a-form-item>

      <a-space>
        <NuxtLink v-if="cancelTo" v-slot="{ href, navigate }" :to="cancelTo" custom>
          <a-button :href="href" @click="navigate">Hủy</a-button>
        </NuxtLink>
        <a-button type="primary" html-type="submit">{{ submitLabel ?? 'Lưu' }}</a-button>
      </a-space>
    </div>
  </a-form>
</template>

<style scoped>
.title-input {
  font-size: 18px;
  font-weight: 600;
}

/* Who-can-see on the left, buttons on the right; stacked on phones */
.form-footer {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
}

.status-item {
  flex: 1 1 280px;
  max-width: 380px;
  margin-bottom: 0;
}
</style>
