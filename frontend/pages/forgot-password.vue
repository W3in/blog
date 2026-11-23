<script setup lang="ts">
definePageMeta({ middleware: 'guest' })
const form = reactive({ email: '' })
const sent = ref(false)
const loading = ref(false)

async function submit() {
  loading.value = true
  try {
    await $fetch('/api/password', { method: 'POST', body: { email: form.email } })
    sent.value = true
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Quên mật khẩu" subtitle="Nhập email, chúng tôi gửi link đặt lại mật khẩu">
    <template #icon><MailOutlined /></template>

    <!-- Same message whether or not the email exists: Rails gives the same answer too -->
    <a-result v-if="sent" status="success" title="Kiểm tra email của bạn"
      :sub-title="`Nếu ${form.email} đã đăng ký, link đặt lại mật khẩu đã được gửi. Link hết hạn sau 15 phút.`" />

    <a-form v-else layout="vertical" :model="form" @finish="submit">
      <a-form-item label="Email" name="email" :rules="[{ required: true, type: 'email', message: 'Nhập email hợp lệ' }]">
        <a-input v-model:value="form.email" size="large" placeholder="you@example.com" autocomplete="email">
          <template #prefix><MailOutlined /></template>
        </a-input>
      </a-form-item>
      <a-button type="primary" html-type="submit" size="large" block :loading="loading">Gửi link</a-button>
    </a-form>

    <template #footer><NuxtLink to="/login">Quay lại đăng nhập</NuxtLink></template>
  </AuthCard>
</template>
