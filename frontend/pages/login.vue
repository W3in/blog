<script setup lang="ts">
const { login } = useAuth()
const form = reactive({ email: '', password: '' })
const error = ref('')

async function submit() {
  try {
    await login(form.email, form.password)
    await navigateTo('/')
  } catch (e: any) {
    if (e.status !== 401) throw e
    error.value = 'Sai email hoặc mật khẩu'
  }
}
</script>

<template>
  <main>
    <h1 class="page-title">Đăng nhập</h1>
    <a-card>
      <a-alert v-if="error" type="error" :message="error" show-icon class="form-alert" />
      <a-form layout="vertical" :model="form" @finish="submit">
        <a-form-item label="Email" name="email" :rules="[{ required: true, type: 'email', message: 'Nhập email hợp lệ' }]">
          <a-input v-model:value="form.email" />
        </a-form-item>
        <a-form-item label="Mật khẩu" name="password" :rules="[{ required: true, message: 'Nhập mật khẩu' }]">
          <a-input-password v-model:value="form.password" />
        </a-form-item>
        <a-button type="primary" html-type="submit" block>Đăng nhập</a-button>
      </a-form>
      <p class="switch">Chưa có tài khoản? <NuxtLink to="/register">Đăng ký</NuxtLink></p>
    </a-card>
  </main>
</template>

<style scoped>
.form-alert { margin-bottom: 16px; }
.switch { margin: 16px 0 0; text-align: center; }
</style>