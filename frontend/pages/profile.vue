<script setup lang="ts">
// Parent page of /profile, /profile/email, /profile/password, /profile/delete (Nuxt nested routes:
// pages/profile.vue + the pages/profile/ folder). It draws the sidebar; <NuxtPage /> shows the chosen section.
// The middleware here also guards every child page
definePageMeta({ middleware: 'auth' })
const { user } = useAuth()
</script>

<template>
  <main v-if="user" class="profile-page">
    <h1 class="page-title">Hồ sơ của tôi</h1>

    <div class="profile-layout">
      <aside class="profile-side">
        <div class="side-card">
          <UserAvatar :name="user.name" :src="user.avatar_url" :size="72" />
          <div class="side-info">
            <div class="side-name">{{ user.name }}</div>
            <div class="muted side-email">{{ user.email }}</div>
            <div class="muted side-since">Thành viên từ {{ formatDate(user.created_at) }}</div>
            <NuxtLink :to="`/users/${user.id}`" class="side-public"><EyeOutlined /> Xem trang công khai</NuxtLink>
          </div>
        </div>

        <!-- RouterLink marks the current page with aria-current="page": the CSS styles that, screen readers read it -->
        <nav class="side-nav" aria-label="Mục hồ sơ">
          <NuxtLink to="/profile" class="side-link"><UserOutlined /> Thông tin cá nhân</NuxtLink>
          <NuxtLink to="/profile/email" class="side-link"><MailOutlined /> Email</NuxtLink>
          <NuxtLink to="/profile/password" class="side-link"><LockOutlined /> Mật khẩu</NuxtLink>
          <NuxtLink to="/profile/delete" class="side-link danger"><DeleteOutlined /> Xóa tài khoản</NuxtLink>
        </nav>
      </aside>

      <section class="profile-main">
        <NuxtPage />
      </section>
    </div>
  </main>
</template>

<style scoped>
.profile-layout {
  display: grid;
  /* fixed sidebar, the section takes the rest. minmax(0, …): a plain 1fr never shrinks below its content,
     so the one-line menu on phones would push the whole page wider than the screen */
  grid-template-columns: 240px minmax(0, 1fr);
  gap: 24px;
  align-items: start;
}

/* Stays in view while a long section scrolls (60px header + a little space) */
.profile-side {
  position: sticky;
  top: 76px;
}

.side-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 24px 16px 16px;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  background: #fff;
  text-align: center;
}

.side-info {
  min-width: 0; /* lets long names/emails wrap inside the card on phones */
}

.side-name {
  font-size: 16px;
  font-weight: 600;
  overflow-wrap: anywhere; /* a 50-letter name without spaces still wraps */
}

.side-email {
  font-size: 13px;
  overflow-wrap: anywhere;
}

.side-since {
  margin-top: 2px;
  font-size: 12px;
}

.side-public {
  display: inline-block;
  margin-top: 8px;
  font-size: 13px;
  text-decoration: none;
}

.side-nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin-top: 12px;
  padding: 6px;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  background: #fff;
}

.side-link {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 8px;
  color: rgba(0, 0, 0, 0.75);
  text-decoration: none;
  white-space: nowrap;
  transition: background 0.2s, color 0.2s;
}

.side-link:hover {
  background: #f5f5f5;
}

.side-link[aria-current='page'] {
  background: #e6f4ff;
  color: #1677ff;
  font-weight: 600;
}

.side-link.danger {
  color: #ff4d4f;
}

.side-link.danger[aria-current='page'] {
  background: #fff1f0;
}

/* Phones and narrow tablets: sidebar on top, the menu becomes one row you can swipe sideways */
@media (max-width: 720px) {
  .profile-layout {
    grid-template-columns: minmax(0, 1fr);
    gap: 16px;
  }

  .profile-side {
    position: static;
  }

  /* Avatar on the left, the text beside it */
  .side-card {
    flex-direction: row;
    gap: 16px;
    padding: 16px;
    text-align: left;
  }

  .side-nav {
    flex-direction: row;
    overflow-x: auto;
  }
}
</style>
