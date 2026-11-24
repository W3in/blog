<script setup lang="ts">
import { message } from 'ant-design-vue'

definePageMeta({ middleware: 'auth' })
const { user, token, headers } = useAuth()

// --- Rename ---
const nameForm = reactive({ name: user.value?.name ?? '' })
const nameErrors = ref<Record<string, string[]>>({})
const savingName = ref(false)

async function saveName() {
  savingName.value = true
  nameErrors.value = {}
  try {
    // Rails answers with the updated user: putting it in useState updates the header at once
    user.value = await $fetch('/api/profile', { method: 'PATCH', body: { profile: nameForm }, headers: headers.value })
    message.success('Đã đổi tên')
  } catch (e: any) {
    if (e.status !== 422) throw e
    nameErrors.value = e.data
  } finally {
    savingName.value = false
  }
}

// --- Change password ---
const pwForm = reactive({ password_challenge: '', password: '', password_confirmation: '' })
const pwErrors = ref<Record<string, string[]>>({})
const savingPw = ref(false)
const pwFormRef = ref()

const confirmRules = [
  { required: true, message: 'Nhập lại mật khẩu mới' },
  {
    validator: (_rule: any, value: string) =>
      value === pwForm.password ? Promise.resolve() : Promise.reject('Mật khẩu nhập lại không khớp')
  }
]

async function savePassword() {
  savingPw.value = true
  pwErrors.value = {}
  try {
    const res = await $fetch<{ token: string }>('/api/profile/password', { method: 'PATCH', body: pwForm, headers: headers.value })
    // Rails changed the token (logging out every other device): keep this one logged in with the new one
    token.value = res.token
    pwFormRef.value.resetFields()
    message.success('Đã đổi mật khẩu. Các thiết bị khác đã bị đăng xuất.')
  } catch (e: any) {
    if (e.status !== 422) throw e
    pwErrors.value = e.data // { password_challenge: ["is invalid"] } when the current password is wrong
  } finally {
    savingPw.value = false
  }
}
</script>

<template>
  <main>
    <NuxtLink to="/" class="back-link"><ArrowLeftOutlined /> Tất cả bài viết</NuxtLink>
    <h1 class="page-title">Hồ sơ của tôi</h1>

    <a-card title="Tên hiển thị" class="profile-card">
      <a-form layout="vertical" :model="nameForm" @finish="saveName">
        <a-form-item name="name" :rules="[{ required: true, min: 2, message: 'Tên từ 2 đến 50 ký tự' }]" v-bind="fieldState(nameErrors, 'name', 'Tên')">
          <a-input v-model:value="nameForm.name" :maxlength="50" show-count autocomplete="name" />
        </a-form-item>
        <p class="muted hint">Bình luận cũ vẫn giữ tên lúc bạn viết; người đọc rê chuột (hoặc chạm) vào sẽ thấy tên hiện tại của bạn. Bình luận ẩn danh không bị ảnh hưởng.</p>
        <a-button type="primary" html-type="submit" :loading="savingName">Lưu tên</a-button>
      </a-form>
    </a-card>

    <a-card title="Đổi mật khẩu" class="profile-card">
      <a-form ref="pwFormRef" layout="vertical" :model="pwForm" @finish="savePassword">
        <a-form-item label="Mật khẩu hiện tại" name="password_challenge" :rules="[{ required: true, message: 'Nhập mật khẩu hiện tại' }]" v-bind="fieldState(pwErrors, 'password_challenge', 'Mật khẩu hiện tại')">
          <a-input-password v-model:value="pwForm.password_challenge" autocomplete="current-password" />
        </a-form-item>
        <a-form-item label="Mật khẩu mới" name="password" :rules="[{ required: true, min: 6, message: 'Ít nhất 6 ký tự' }]" v-bind="fieldState(pwErrors, 'password', 'Mật khẩu')">
          <a-input-password v-model:value="pwForm.password" autocomplete="new-password" />
        </a-form-item>
        <a-form-item label="Nhập lại mật khẩu mới" name="password_confirmation" :rules="confirmRules" v-bind="fieldState(pwErrors, 'password_confirmation', 'Nhập lại')">
          <a-input-password v-model:value="pwForm.password_confirmation" autocomplete="new-password" />
        </a-form-item>
        <p class="muted hint">Đổi xong, mọi thiết bị khác sẽ bị đăng xuất; máy này vẫn giữ đăng nhập.</p>
        <a-button type="primary" html-type="submit" :loading="savingPw">Đổi mật khẩu</a-button>
      </a-form>
    </a-card>
  </main>
</template>

<style scoped>
.profile-card {
  margin-bottom: 16px;
}

.hint {
  margin-bottom: 16px;
}
</style>
