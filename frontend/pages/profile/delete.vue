<script setup lang="ts">
import { message } from 'ant-design-vue'

// /profile/delete: permanent, so it asks for the password AND a ticked box
const { user, token, headers } = useAuth()
const form = reactive({ password_challenge: '', understood: false })
const errors = ref<Record<string, string[]>>({})
const deleting = ref(false)

const understoodRules = [{
  validator: (_rule: any, value: boolean) =>
    value ? Promise.resolve() : Promise.reject('Hãy đánh dấu để xác nhận')
}]

async function destroyAccount() {
  deleting.value = true
  errors.value = {}
  try {
    // $fetch sends a DELETE body as JSON, Rails reads it like any other params
    await $fetch('/api/profile', { method: 'DELETE', body: { password_challenge: form.password_challenge }, headers: headers.value })
    // The token no longer exists in Rails: forget it here too
    token.value = null
    user.value = null
    message.success('Đã xóa tài khoản')
    await navigateTo('/')
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data
  } finally {
    deleting.value = false
  }
}
</script>

<template>
  <a-card title="Xóa tài khoản" class="danger-card">
    <a-alert type="error" show-icon message="Không thể hoàn tác" class="warning">
      <template #description>
        Tài khoản, mọi bài viết của bạn (cùng bình luận của người khác trong các bài đó), mọi bình luận bạn đã viết và ảnh đại diện sẽ bị xóa vĩnh viễn.
      </template>
    </a-alert>

    <a-form layout="vertical" :model="form" @finish="destroyAccount">
      <a-form-item label="Mật khẩu hiện tại" name="password_challenge" :rules="[{ required: true, message: 'Nhập mật khẩu để xác nhận' }]" v-bind="fieldState(errors, 'password_challenge', 'Mật khẩu')">
        <a-input-password v-model:value="form.password_challenge" autocomplete="current-password" />
      </a-form-item>
      <a-form-item name="understood" :rules="understoodRules">
        <a-checkbox v-model:checked="form.understood">Tôi hiểu tài khoản {{ user?.email }} sẽ bị xóa vĩnh viễn</a-checkbox>
      </a-form-item>
      <a-button type="primary" danger html-type="submit" :loading="deleting"><DeleteOutlined /> Xóa vĩnh viễn tài khoản</a-button>
    </a-form>
  </a-card>
</template>

<style scoped>
.danger-card {
  border-color: #ffccc7;
}

.warning {
  margin-bottom: 20px;
}
</style>
