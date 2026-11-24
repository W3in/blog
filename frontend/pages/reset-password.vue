<script setup lang="ts">
definePageMeta({ middleware: 'guest' })
// The token comes from the link in the email: /reset-password?token=...
const token = useRoute().query.token
const form = reactive({ password: '', password_confirmation: '' })
const errors = ref<Record<string, string[]>>({})
const loading = ref(false)

const confirmRules = [
  { required: true, message: 'Nhập lại mật khẩu' },
  {
    validator: (_rule: any, value: string) =>
      value === form.password ? Promise.resolve() : Promise.reject('Mật khẩu nhập lại không khớp')
  }
]

async function submit() {
  loading.value = true
  errors.value = {}
  try {
    await $fetch('/api/password', { method: 'PATCH', body: { token, ...form } })
    await navigateTo('/login?reset=1')
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data // { token: [...] } when the link is wrong or expired
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Đặt lại mật khẩu" subtitle="Chọn mật khẩu mới cho tài khoản của bạn">
    <template #icon><LockOutlined /></template>

    <a-alert v-if="errors.token" type="error" show-icon class="form-alert"
      message="Link không hợp lệ hoặc đã hết hạn (15 phút, chỉ dùng được một lần)">
      <template #description><NuxtLink to="/forgot-password">Gửi lại link mới</NuxtLink></template>
    </a-alert>

    <a-form layout="vertical" :model="form" @finish="submit">
      <a-form-item label="Mật khẩu mới" name="password" :rules="[{ required: true, min: 6, message: 'Ít nhất 6 ký tự' }]" v-bind="fieldState(errors, 'password', 'Mật khẩu')">
        <a-input-password v-model:value="form.password" size="large" placeholder="Ít nhất 6 ký tự" autocomplete="new-password">
          <template #prefix><LockOutlined /></template>
        </a-input-password>
      </a-form-item>

      <a-form-item label="Nhập lại mật khẩu" name="password_confirmation" :rules="confirmRules" v-bind="fieldState(errors, 'password_confirmation', 'Mật khẩu nhập lại')">
        <a-input-password v-model:value="form.password_confirmation" size="large" placeholder="Nhập lại mật khẩu" autocomplete="new-password">
          <template #prefix><LockOutlined /></template>
        </a-input-password>
      </a-form-item>

      <a-button type="primary" html-type="submit" size="large" block :loading="loading">Đổi mật khẩu</a-button>
    </a-form>

    <template #footer><NuxtLink to="/login">Quay lại đăng nhập</NuxtLink></template>
  </AuthCard>
</template>

<style scoped>
.form-alert {
  margin-bottom: 16px;
}
</style>
