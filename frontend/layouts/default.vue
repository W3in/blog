<script setup lang="ts">
const { user, logout } = useAuth()
</script>

<template>
  <div class="site">
    <header class="site-header">
      <div class="site-header-inner">
        <NuxtLink to="/" class="brand">
          <span class="brand-icon"><ReadOutlined /></span>
          Blog của tôi
        </NuxtLink>

        <!-- custom: NuxtLink gives the href, a-button draws it, so it is one real <a> (no button inside a link) -->
        <a-space :size="12">
          <template v-if="user">
            <NuxtLink v-slot="{ href, navigate }" to="/articles/new" custom>
              <!-- aria-label: on phones the text is hidden, screen readers still need a name -->
              <a-button type="primary" :href="href" aria-label="Viết bài" @click="navigate">
                <EditOutlined /><span class="hide-mobile">Viết bài</span>
              </a-button>
            </NuxtLink>

            <NotificationBell />

            <!-- Name + logout live in a menu, so the header stays one short row on phones -->
            <a-dropdown placement="bottomRight" :trigger="['click']">
              <button type="button" class="user-menu">
                <UserAvatar :name="user.name" :src="user.avatar_url" size="small" />
                <span class="hide-mobile">{{ user.name }}</span>
                <DownOutlined class="caret" />
              </button>
              <template #overlay>
                <a-menu>
                  <a-menu-item key="email" disabled>{{ user.email }}</a-menu-item>
                  <a-menu-item key="page" @click="navigateTo(`/users/${user.id}`)"><IdcardOutlined /> Trang cá nhân</a-menu-item>
                  <a-menu-item key="profile" @click="navigateTo('/profile')"><SettingOutlined /> Hồ sơ của tôi</a-menu-item>
                  <a-menu-divider />
                  <a-menu-item key="logout" danger @click="logout"><LogoutOutlined /> Đăng xuất</a-menu-item>
                </a-menu>
              </template>
            </a-dropdown>
          </template>

          <template v-else>
            <NuxtLink v-slot="{ href, navigate }" to="/login" custom>
              <a-button type="primary" :href="href" @click="navigate">Đăng nhập</a-button>
            </NuxtLink>
            <NuxtLink v-slot="{ href, navigate }" to="/register" custom>
              <a-button type="primary" :href="href" @click="navigate">Đăng ký</a-button>
            </NuxtLink>
          </template>
        </a-space>
      </div>
    </header>

    <div class="site-content">
      <slot />
    </div>

    <footer class="site-footer">© {{ new Date().getFullYear() }} Blog của tôi</footer>
  </div>
</template>

<style scoped>
/* Column layout: content grows, so the footer stays at the bottom even on short pages */
.site {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

/* Slightly see-through white + blur: content scrolling under the sticky header stays faintly visible */
.site-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background: rgba(255, 255, 255, 0.85);
  backdrop-filter: blur(8px);
  border-bottom: 1px solid #f0f0f0;
}

.site-header-inner {
  max-width: 800px;
  height: 60px;
  margin: 0 auto;
  padding: 0 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.brand {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 20px;
  font-weight: 700;
  color: rgba(0, 0, 0, 0.88);
  text-decoration: none;
  white-space: nowrap; /* "Blog của tôi" stays on one line next to the buttons on phones */
}

.brand-icon {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: #1677ff;
  color: #fff;
  font-size: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* Plain <button> styled by us: a-button would fight our flex layout for avatar + name + caret */
.user-menu {
  display: flex;
  align-items: center;
  gap: 8px;
  height: 36px;
  padding: 0 8px 0 4px;
  border: 1px solid #f0f0f0;
  border-radius: 18px;
  background: #fff;
  font: inherit;
  cursor: pointer;
  transition: border-color 0.2s;
}

.user-menu:hover,
.user-menu:focus-visible {
  border-color: #1677ff;
}

.caret {
  font-size: 10px;
  color: rgba(0, 0, 0, 0.45);
}

.site-content {
  flex: 1;
}

.site-footer {
  padding: 24px 16px;
  text-align: center;
  color: rgba(0, 0, 0, 0.45);
}

/* Phones: icon-only "+" button and avatar-only menu so everything fits in 375px */
@media (max-width: 576px) {
  .hide-mobile {
    display: none;
  }

  .brand {
    font-size: 17px;
  }
}
</style>
