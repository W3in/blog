<script setup lang="ts">
import { message } from 'ant-design-vue'

// /profile/email: new address, confirmed with the current password
const { user, headers } = useAuth()
const form = reactive({ email: '', password_challenge: '' })
const errors = ref<Record<string, string[]>>({})
const saving = ref(false)
const formRef = ref()

async function save() {
  saving.value = true
  errors.value = {}
  try {
    user.value = await $fetch('/api/profile/email', { method: 'PATCH', body: form, headers: headers.value })
    formRef.value.resetFields() // empty both boxes, the new address now shows above
    message.success('Đã đổi email')
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <a-card v-if="user" title="Email">
    <p class="current">Email hiện tại: <strong>{{ user.email }}</strong></p>
    <p class="muted hint">Email dùng để đăng nhập và nhận link đặt lại mật khẩu. Người khác không thấy email của bạn.</p>

    <a-form ref="formRef" layout="vertical" :model="form" @finish="save">
      <a-form-item label="Email mới" name="email" :rules="[{ required: true, type: 'email', message: 'Nhập đúng định dạng email' }]" v-bind="fieldState(errors, 'email', 'Email')">
        <a-input v-model:value="form.email" type="email" autocomplete="email" placeholder="ban@vidu.com" />
      </a-form-item>
      <a-form-item label="Mật khẩu hiện tại" name="password_challenge" :rules="[{ required: true, message: 'Nhập mật khẩu để xác nhận' }]" v-bind="fieldState(errors, 'password_challenge', 'Mật khẩu')">
        <a-input-password v-model:value="form.password_challenge" autocomplete="current-password" />
      </a-form-item>
      <a-button type="primary" html-type="submit" :loading="saving">Đổi email</a-button>
    </a-form>
  </a-card>
</template>

<style scoped>
.current {
  margin: 0 0 4px;
  overflow-wrap: anywhere;
}

.hint {
  margin: 0 0 16px;
  font-size: 13px;
}
</style>
