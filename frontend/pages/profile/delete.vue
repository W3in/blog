<script setup lang="ts">
import { message } from 'ant-design-vue'

// /profile/delete: Reddit-style. Asks for the password AND a ticked box, because it cannot be undone
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
  <a-form layout="vertical" :model="form" @finish="destroyAccount">
    <SettingsPanel title="Xóa tài khoản" description="Giống Reddit: những gì bạn đã viết vẫn ở lại cho cuộc thảo luận, nhưng không còn gắn với bạn." danger>
      <div class="effects">
        <div class="effect keep">
          <div class="effect-title"><CheckCircleOutlined /> Vẫn giữ lại</div>
          <ul>
            <li>Bài viết và bình luận của bạn</li>
            <li>Tác giả hiện là <strong>[đã xóa]</strong></li>
            <li>Bình luận của người khác trong bài của bạn</li>
          </ul>
        </div>
        <div class="effect gone">
          <div class="effect-title"><CloseCircleOutlined /> Bị xóa vĩnh viễn</div>
          <ul>
            <li>Tên, email ({{ user?.email }}) và ảnh đại diện</li>
            <li>Trang cá nhân công khai</li>
            <li>Đăng nhập: không vào lại được tài khoản này</li>
          </ul>
        </div>
      </div>

      <a-form-item label="Mật khẩu hiện tại" name="password_challenge" :rules="[{ required: true, message: 'Nhập mật khẩu để xác nhận' }]" v-bind="fieldState(errors, 'password_challenge', 'Mật khẩu')">
        <a-input-password v-model:value="form.password_challenge" size="large" autocomplete="current-password" />
      </a-form-item>
      <a-form-item name="understood" :rules="understoodRules" class="last-item">
        <a-checkbox v-model:checked="form.understood">Tôi hiểu việc này không thể hoàn tác</a-checkbox>
      </a-form-item>

      <template #footer>
        <a-button type="primary" danger html-type="submit" :loading="deleting"><DeleteOutlined /> Xóa tài khoản</a-button>
      </template>
    </SettingsPanel>
  </a-form>
</template>

<style scoped>
/* Two boxes side by side (one under the other on phones): what stays, what goes */
.effects {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
  margin-bottom: 20px;
}

.effect {
  padding: 12px 16px;
  border-radius: 10px;
}

.effect.keep {
  background: #f6ffed;
}

.effect.gone {
  background: #fff1f0;
}

.effect-title {
  margin-bottom: 6px;
  font-weight: 600;
}

.keep .effect-title {
  color: #389e0d;
}

.gone .effect-title {
  color: #cf1322;
}

.effect ul {
  margin: 0;
  padding-left: 18px;
  color: rgba(0, 0, 0, 0.7);
  font-size: 13px;
}

.last-item {
  margin-bottom: 0;
}
</style>
