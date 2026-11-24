<script setup lang="ts">
// Parent page of /profile, /profile/email, /profile/password, /profile/delete (Nuxt nested routes:
// pages/profile.vue + the pages/profile/ folder). It draws the header and the menu; <NuxtPage /> shows the
// chosen section. The middleware here also guards every child page
definePageMeta({ middleware: 'auth' })
const { user } = useAuth()
</script>

<template>
  <main v-if="user" class="profile-page">
    <ProfileHeader :name="user.name" :avatar-url="user.avatar_url">
      <template #meta>
        <span><MailOutlined /> {{ user.email }}</span>
        <span><CalendarOutlined /> Thành viên từ {{ formatDate(user.created_at) }}</span>
      </template>
      <template #actions>
        <NuxtLink v-slot="{ href, navigate }" :to="`/users/${user.id}`" custom>
          <a-button :href="href" @click="navigate"><EyeOutlined /> Xem trang công khai</a-button>
        </NuxtLink>
      </template>
    </ProfileHeader>

    <div class="profile-layout">
      <!-- RouterLink marks the current page with aria-current="page": the CSS styles that, screen readers read it.
           Icons are written out one by one: Nuxt imports an icon only when it sees its tag in the template -->
      <nav class="side-nav" aria-label="Mục hồ sơ">
        <NuxtLink to="/profile" class="side-link">
          <span class="side-icon"><UserOutlined /></span>
          <span class="side-text"><span class="side-title">Thông tin cá nhân</span><span class="side-desc">Ảnh đại diện, tên hiển thị</span></span>
        </NuxtLink>
        <NuxtLink to="/profile/email" class="side-link">
          <span class="side-icon"><MailOutlined /></span>
          <span class="side-text"><span class="side-title">Email</span><span class="side-desc">Địa chỉ đăng nhập</span></span>
        </NuxtLink>
        <NuxtLink to="/profile/password" class="side-link">
          <span class="side-icon"><LockOutlined /></span>
          <span class="side-text"><span class="side-title">Mật khẩu</span><span class="side-desc">Đổi mật khẩu đăng nhập</span></span>
        </NuxtLink>
        <NuxtLink to="/profile/delete" class="side-link danger">
          <span class="side-icon"><DeleteOutlined /></span>
          <span class="side-text"><span class="side-title">Xóa tài khoản</span><span class="side-desc">Không thể hoàn tác</span></span>
        </NuxtLink>
      </nav>

      <section class="profile-main">
        <NuxtPage />
      </section>
    </div>
  </main>
</template>

<style scoped>
.profile-layout {
  display: grid;
  /* fixed menu, the section takes the rest. minmax(0, …): a plain 1fr never shrinks below its content,
     so the one-line menu on phones would push the whole page wider than the screen */
  grid-template-columns: 230px minmax(0, 1fr);
  gap: 20px;
  align-items: start;
}

/* Stays in view while a long section scrolls (60px header + a little space) */
.side-nav {
  position: sticky;
  top: 76px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.side-link {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 12px;
  border-radius: 10px;
  color: rgba(0, 0, 0, 0.8);
  text-decoration: none;
  transition: background 0.2s;
}

.side-link:hover {
  background: #fff;
}

.side-icon {
  display: grid;
  place-items: center;
  flex: none;
  width: 34px;
  height: 34px;
  border: 1px solid #f0f0f0;
  border-radius: 9px;
  background: #fff;
  color: rgba(0, 0, 0, 0.6);
  font-size: 16px;
}

.side-text {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.side-title {
  font-weight: 500;
}

.side-desc {
  color: rgba(0, 0, 0, 0.45);
  font-size: 12px;
}

/* Current section: white card, filled blue icon, a blue bar on the left edge */
.side-link[aria-current='page'] {
  background: #fff;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}

.side-link[aria-current='page']::before {
  content: '';
  position: absolute;
  left: 0;
  top: 12px;
  bottom: 12px;
  width: 3px;
  border-radius: 3px;
  background: #1677ff;
}

.side-link[aria-current='page'] .side-icon {
  border-color: #1677ff;
  background: #1677ff;
  color: #fff;
}

.side-link[aria-current='page'] .side-title {
  font-weight: 600;
}

.side-link.danger .side-title,
.side-link.danger .side-icon {
  color: #cf1322;
}

.side-link.danger[aria-current='page'] .side-icon {
  border-color: #ff4d4f;
  background: #ff4d4f;
  color: #fff;
}

.side-link.danger[aria-current='page']::before {
  background: #ff4d4f;
}

/* Phones and narrow tablets: the menu becomes one row of chips you can swipe sideways */
@media (max-width: 720px) {
  .profile-layout {
    grid-template-columns: minmax(0, 1fr);
    gap: 12px;
  }

  .side-nav {
    position: static;
    flex-direction: row;
    overflow-x: auto;
    padding-bottom: 4px;
  }

  .side-link {
    flex: none;
    padding: 6px 14px 6px 6px;
    border: 1px solid #f0f0f0;
    border-radius: 999px;
    background: #fff;
  }

  .side-icon {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    font-size: 14px;
  }

  .side-desc,
  .side-link[aria-current='page']::before {
    display: none;
  }
}
</style>
