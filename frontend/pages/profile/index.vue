<script setup lang="ts">
import { message } from 'ant-design-vue'

// /profile: avatar + display name
const { user, headers } = useAuth()

// --- Avatar ---
const fileInput = ref<HTMLInputElement>()
const uploading = ref(false)

async function pickAvatar(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = '' // so picking the same file again still fires "change"
  if (!file) return

  uploading.value = true
  try {
    const body = new FormData()
    body.append('file', await squareImage(file), 'avatar.jpg') // cropped + shrunk in the browser first
    // Rails answers with the updated user: the header, menu and comments all read this same useState
    user.value = await $fetch('/api/profile/avatar', { method: 'PUT', body, headers: headers.value })
    message.success('Đã đổi ảnh đại diện')
  } catch (e: any) {
    // 422 from Rails has { file: [...] }; anything else here means the browser could not read the picture
    message.error(e.data?.file ? `Ảnh ${e.data.file.join(', ')}` : 'Không đọc được ảnh này, hãy thử ảnh PNG hoặc JPG')
  } finally {
    uploading.value = false
  }
}

async function removeAvatar() {
  user.value = await $fetch('/api/profile/avatar', { method: 'DELETE', headers: headers.value })
  message.success('Đã gỡ ảnh đại diện')
}

// --- Display name ---
const nameForm = reactive({ name: user.value?.name ?? '' })
const nameErrors = ref<Record<string, string[]>>({})
const savingName = ref(false)
const nameChanged = computed(() => nameForm.name.trim() !== user.value?.name)

async function saveName() {
  savingName.value = true
  nameErrors.value = {}
  try {
    user.value = await $fetch('/api/profile', { method: 'PATCH', body: { profile: nameForm }, headers: headers.value })
    message.success('Đã đổi tên')
  } catch (e: any) {
    if (e.status !== 422) throw e
    nameErrors.value = e.data
  } finally {
    savingName.value = false
  }
}
</script>

<template>
  <div v-if="user">
    <SettingsPanel title="Ảnh đại diện" description="Hiện cạnh bài viết và bình luận của bạn (trừ bình luận ẩn danh).">
      <div class="avatar-edit">
        <!-- The avatar itself is the button: hover or focus shows "Đổi ảnh" over it -->
        <button type="button" class="avatar-button" :disabled="uploading" aria-label="Đổi ảnh đại diện" @click="fileInput?.click()">
          <UserAvatar :name="user.name" :src="user.avatar_url" :size="88" />
          <span class="avatar-overlay"><LoadingOutlined v-if="uploading" /><CameraOutlined v-else /></span>
        </button>
        <div class="avatar-side">
          <a-space wrap>
            <a-button type="primary" :loading="uploading" @click="fileInput?.click()"><UploadOutlined /> Tải ảnh lên</a-button>
            <a-popconfirm v-if="user.avatar_url" title="Gỡ ảnh đại diện?" ok-text="Gỡ" cancel-text="Hủy" @confirm="removeAvatar">
              <a-button>Gỡ ảnh</a-button>
            </a-popconfirm>
          </a-space>
          <p class="hint">PNG, JPG, GIF hoặc WebP. Ảnh được cắt vuông ở giữa và thu nhỏ trước khi tải lên.</p>
        </div>
        <!-- The real file input is hidden; the buttons open it -->
        <input ref="fileInput" type="file" accept="image/png,image/jpeg,image/gif,image/webp" hidden @change="pickAvatar">
      </div>
    </SettingsPanel>

    <!-- The form wraps the whole panel so the Save button in the footer can submit it -->
    <a-form layout="vertical" :model="nameForm" @finish="saveName">
      <SettingsPanel title="Tên hiển thị" description="Tên mọi người thấy cạnh bài viết và bình luận của bạn.">
        <a-form-item name="name" :rules="[{ required: true, min: 2, message: 'Tên từ 2 đến 50 ký tự' }]" v-bind="fieldState(nameErrors, 'name', 'Tên')" class="last-item">
          <a-input v-model:value="nameForm.name" size="large" :maxlength="50" show-count autocomplete="name" />
        </a-form-item>
        <template #footer>
          <span class="footer-note"><InfoCircleOutlined /> Bình luận cũ vẫn giữ tên lúc viết; rê chuột vào sẽ thấy tên mới.</span>
          <a-button type="primary" html-type="submit" :loading="savingName" :disabled="!nameChanged">Lưu tên</a-button>
        </template>
      </SettingsPanel>
    </a-form>
  </div>
</template>

<style scoped>
.avatar-edit {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 20px;
}

/* A round button around the avatar; the dark layer + camera fade in on hover / keyboard focus */
.avatar-button {
  position: relative;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: none;
  cursor: pointer;
}

.avatar-overlay {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.45);
  color: #fff;
  font-size: 24px;
  opacity: 0;
  transition: opacity 0.2s;
}

.avatar-button:hover .avatar-overlay,
.avatar-button:focus-visible .avatar-overlay,
.avatar-button:disabled .avatar-overlay {
  opacity: 1;
}

.avatar-side {
  flex: 1;
  min-width: 220px;
}

.hint {
  margin: 10px 0 0;
  color: rgba(0, 0, 0, 0.45);
  font-size: 13px;
}

.last-item {
  margin-bottom: 0;
}

/* Footer: note on the left, button on the right */
.footer-note {
  flex: 1;
  color: rgba(0, 0, 0, 0.45);
  font-size: 12px;
}
</style>
