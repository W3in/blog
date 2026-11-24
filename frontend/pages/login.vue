<script setup lang="ts">
definePageMeta({ middleware: 'guest' })
const { login } = useAuth()
const route = useRoute()
const form = reactive({ email: '', password: '' })
const error = ref('')
const loading = ref(false)

async function submit() {
  loading.value = true
  error.value = ''
  try {
    await login(form.email, form.password)
    const redirect = route.query.redirect
    await navigateTo(typeof redirect === 'string' && redirect.startsWith('/') ? redirect : '/')
  } catch (e: any) {
    if (e.status !== 401) throw e
    // Same message for wrong email and wrong password, so nobody can probe which emails exist
    error.value = 'Sai email hoặc mật khẩu'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Đăng nhập" subtitle="Chào mừng bạn quay lại Blog của tôi">
    <template #icon><LoginOutlined /></template>

    <!-- reset-password.vue sends people here with ?reset=1 after a successful reset -->
    <a-alert v-if="route.query.reset" type="success" message="Đã đổi mật khẩu, hãy đăng nhập bằng mật khẩu mới" show-icon class="form-alert" />
    <a-alert v-if="error" type="error" :message="error" show-icon class="form-alert" />

    <a-form layout="vertical" :model="form" @finish="submit">
      <a-form-item label="Email" name="email" :rules="[{ required: true, type: 'email', message: 'Nhập email hợp lệ' }]">
        <a-input v-model:value="form.email" size="large" placeholder="you@example.com" autocomplete="email">
          <template #prefix><MailOutlined /></template>
        </a-input>
      </a-form-item>

      <a-form-item label="Mật khẩu" name="password" :rules="[{ required: true, message: 'Nhập mật khẩu' }]">
        <a-input-password v-model:value="form.password" size="large" placeholder="Mật khẩu" autocomplete="current-password">
          <template #prefix><LockOutlined /></template>
        </a-input-password>
      </a-form-item>

      <p class="forgot"><NuxtLink to="/forgot-password">Quên mật khẩu?</NuxtLink></p>

      <a-button type="primary" html-type="submit" size="large" block :loading="loading">Đăng nhập</a-button>
    </a-form>

    <template #footer>Chưa có tài khoản? <NuxtLink to="/register">Đăng ký</NuxtLink></template>
  </AuthCard>
</template>

<style scoped>
.form-alert {
  margin-bottom: 16px;
}

.forgot {
  margin: -8px 0 16px;
  text-align: right;
}
</style>
