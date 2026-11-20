<script setup lang="ts">
const { register } = useAuth()
const form = reactive({ name: '', email: '', password: '', password_confirmation: '' })
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
    await register(form)
    await navigateTo('/')
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data // e.g. { email: ["has already been taken"] }
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Đăng ký" subtitle="Tạo tài khoản để viết bài và bình luận">
    <template #icon><UserAddOutlined /></template>

    <a-form layout="vertical" :model="form" @finish="submit">
      <a-form-item label="Tên hiển thị" name="name" :rules="[{ required: true, message: 'Nhập tên' }]" v-bind="fieldState(errors, 'name', 'Tên')">
        <a-input v-model:value="form.name" size="large" placeholder="Tên của bạn" autocomplete="name">
          <template #prefix><UserOutlined /></template>
        </a-input>
      </a-form-item>

      <a-form-item label="Email" name="email" :rules="[{ required: true, type: 'email', message: 'Nhập email hợp lệ' }]" v-bind="fieldState(errors, 'email', 'Email')">
        <a-input v-model:value="form.email" size="large" placeholder="you@example.com" autocomplete="email">
          <template #prefix><MailOutlined /></template>
        </a-input>
      </a-form-item>

      <a-form-item label="Mật khẩu" name="password" :rules="[{ required: true, min: 6, message: 'Ít nhất 6 ký tự' }]" v-bind="fieldState(errors, 'password', 'Password')">
        <a-input-password v-model:value="form.password" size="large" placeholder="Ít nhất 6 ký tự" autocomplete="new-password">
          <template #prefix><LockOutlined /></template>
        </a-input-password>
      </a-form-item>

      <a-form-item label="Nhập lại mật khẩu" name="password_confirmation" :rules="confirmRules" v-bind="fieldState(errors, 'password_confirmation', 'Password confirmation')">
        <a-input-password v-model:value="form.password_confirmation" size="large" placeholder="Nhập lại mật khẩu" autocomplete="new-password">
          <template #prefix><LockOutlined /></template>
        </a-input-password>
      </a-form-item>

      <a-button type="primary" html-type="submit" size="large" block :loading="loading">Tạo tài khoản</a-button>
    </a-form>

    <template #footer>Đã có tài khoản? <NuxtLink to="/login">Đăng nhập</NuxtLink></template>
  </AuthCard>
</template>
