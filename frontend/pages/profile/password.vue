<script setup lang="ts">
import { message } from 'ant-design-vue'

// /profile/password: needs the current password; other devices get logged out, this one keeps going
const { token, headers } = useAuth()
const form = reactive({ password_challenge: '', password: '', password_confirmation: '' })
const errors = ref<Record<string, string[]>>({})
const saving = ref(false)
const formRef = ref()

const confirmRules = [
  { required: true, message: 'Nhập lại mật khẩu mới' },
  {
    validator: (_rule: any, value: string) =>
      value === form.password ? Promise.resolve() : Promise.reject('Mật khẩu nhập lại không khớp')
  }
]

async function save() {
  saving.value = true
  errors.value = {}
  try {
    const res = await $fetch<{ token: string }>('/api/profile/password', { method: 'PATCH', body: form, headers: headers.value })
    // Rails changed the token (logging out every other device): keep this one logged in with the new one
    token.value = res.token
    formRef.value.resetFields()
    message.success('Đã đổi mật khẩu. Các thiết bị khác đã bị đăng xuất.')
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data // { password_challenge: ["không đúng"] } when the current password is wrong
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <a-form ref="formRef" layout="vertical" :model="form" @finish="save">
    <SettingsPanel title="Đổi mật khẩu" description="Đổi xong, mọi thiết bị khác sẽ bị đăng xuất; máy này vẫn giữ đăng nhập.">
      <a-form-item label="Mật khẩu hiện tại" name="password_challenge" :rules="[{ required: true, message: 'Nhập mật khẩu hiện tại' }]" v-bind="fieldState(errors, 'password_challenge', 'Mật khẩu hiện tại')">
        <a-input-password v-model:value="form.password_challenge" size="large" autocomplete="current-password" />
      </a-form-item>

      <a-divider class="divider" />

      <a-form-item label="Mật khẩu mới" name="password" :rules="[{ required: true, min: 6, message: 'Ít nhất 6 ký tự' }]" v-bind="fieldState(errors, 'password', 'Mật khẩu mới')">
        <a-input-password v-model:value="form.password" size="large" autocomplete="new-password" placeholder="Ít nhất 6 ký tự" />
      </a-form-item>
      <a-form-item label="Nhập lại mật khẩu mới" name="password_confirmation" :rules="confirmRules" v-bind="fieldState(errors, 'password_confirmation', 'Mật khẩu')" class="last-item">
        <a-input-password v-model:value="form.password_confirmation" size="large" autocomplete="new-password" />
      </a-form-item>

      <template #footer>
        <a-button type="primary" html-type="submit" :loading="saving">Đổi mật khẩu</a-button>
      </template>
    </SettingsPanel>
  </a-form>
</template>

<style scoped>
.divider {
  margin: 4px 0 20px;
}

.last-item {
  margin-bottom: 0;
}
</style>
