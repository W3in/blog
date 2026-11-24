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
  <a-form v-if="user" ref="formRef" layout="vertical" :model="form" @finish="save">
    <SettingsPanel title="Email" description="Dùng để đăng nhập và nhận link đặt lại mật khẩu. Người khác không thấy email của bạn.">
      <div class="current">
        <span class="current-icon"><MailOutlined /></span>
        <div class="current-text">
          <div class="current-label">Email hiện tại</div>
          <div class="current-value">{{ user.email }}</div>
        </div>
      </div>

      <a-form-item label="Email mới" name="email" :rules="[{ required: true, type: 'email', message: 'Nhập đúng định dạng email' }]" v-bind="fieldState(errors, 'email', 'Email')">
        <a-input v-model:value="form.email" size="large" type="email" autocomplete="email" placeholder="ban@vidu.com" />
      </a-form-item>
      <a-form-item label="Mật khẩu hiện tại" name="password_challenge" :rules="[{ required: true, message: 'Nhập mật khẩu để xác nhận' }]" v-bind="fieldState(errors, 'password_challenge', 'Mật khẩu')" class="last-item">
        <a-input-password v-model:value="form.password_challenge" size="large" autocomplete="current-password" />
      </a-form-item>

      <template #footer>
        <a-button type="primary" html-type="submit" :loading="saving">Đổi email</a-button>
      </template>
    </SettingsPanel>
  </a-form>
</template>

<style scoped>
/* The current address as a small highlighted row above the form */
.current {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
  padding: 12px 16px;
  border-radius: 10px;
  background: #f6f8fb;
}

.current-icon {
  display: grid;
  place-items: center;
  flex: none;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: #e6f4ff;
  color: #1677ff;
}

.current-text {
  min-width: 0;
}

.current-label {
  color: rgba(0, 0, 0, 0.45);
  font-size: 12px;
}

.current-value {
  font-weight: 600;
  overflow-wrap: anywhere;
}

.last-item {
  margin-bottom: 0;
}
</style>
