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
    // Rails answers with the updated user: the header, sidebar and comments all read this same useState
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
  <div v-if="user" class="sections">
    <a-card title="Ảnh đại diện">
      <div class="avatar-row">
        <UserAvatar :name="user.name" :src="user.avatar_url" :size="96" />
        <div>
          <a-space wrap>
            <!-- The real file input is hidden; the button opens it -->
            <a-button type="primary" :loading="uploading" @click="fileInput?.click()"><UploadOutlined /> Tải ảnh lên</a-button>
            <a-popconfirm v-if="user.avatar_url" title="Gỡ ảnh đại diện?" ok-text="Gỡ" cancel-text="Hủy" @confirm="removeAvatar">
              <a-button>Gỡ ảnh</a-button>
            </a-popconfirm>
          </a-space>
          <p class="muted hint">PNG, JPG, GIF hoặc WebP. Ảnh được cắt vuông ở giữa và thu nhỏ trước khi tải lên.</p>
        </div>
        <input ref="fileInput" type="file" accept="image/png,image/jpeg,image/gif,image/webp" hidden @change="pickAvatar">
      </div>
    </a-card>

    <a-card title="Tên hiển thị">
      <a-form layout="vertical" :model="nameForm" @finish="saveName">
        <a-form-item name="name" :rules="[{ required: true, min: 2, message: 'Tên từ 2 đến 50 ký tự' }]" v-bind="fieldState(nameErrors, 'name', 'Tên')">
          <a-input v-model:value="nameForm.name" :maxlength="50" show-count autocomplete="name" />
        </a-form-item>
        <p class="muted hint">Bình luận cũ vẫn giữ tên lúc bạn viết; người đọc rê chuột (hoặc chạm) vào sẽ thấy tên hiện tại của bạn. Bình luận ẩn danh không bị ảnh hưởng.</p>
        <a-button type="primary" html-type="submit" :loading="savingName">Lưu tên</a-button>
      </a-form>
    </a-card>
  </div>
</template>

<style scoped>
.sections {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.avatar-row {
  display: flex;
  align-items: center;
  gap: 20px;
}

.hint {
  margin: 12px 0 0;
  font-size: 13px;
}

form .hint {
  margin: 0 0 16px;
}
</style>
