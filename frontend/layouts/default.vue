<script setup lang="ts">
const { user, logout } = useAuth()
</script>

<template>
  <div class="site">
    <header class="site-header">
      <div class="site-header-inner">
        <NuxtLink to="/" class="brand">My Blog</NuxtLink>
        <!-- custom: NuxtLink gives the href, a-button draws it, so it is one real <a> (no button inside a link) -->
        <NuxtLink v-slot="{ href, navigate }" to="/articles/new" custom>
          <a-space>
            <template v-if="user">
              <span class="hello">Xin chào, {{ user.name }}</span>
              <NuxtLink v-slot="{ href, navigate }" to="/articles/new" custom>
                <a-button type="primary" :href="href" @click="navigate"><PlusOutlined /> New Article</a-button>
              </NuxtLink>
              <a-button @click="logout"><LogoutOutlined /> Đăng xuất</a-button>
            </template>
            <template v-else>
              <NuxtLink v-slot="{ href, navigate }" to="/login" custom>
                <a-button :href="href" @click="navigate">Đăng nhập</a-button>
              </NuxtLink>
              <NuxtLink v-slot="{ href, navigate }" to="/register" custom>
                <a-button type="primary" :href="href" @click="navigate">Đăng ký</a-button>
              </NuxtLink>
            </template>
          </a-space>
        </NuxtLink>
      </div>
    </header>

    <div class="site-content">
      <slot />
    </div>

    <footer class="site-footer">© {{ new Date().getFullYear() }} My Blog</footer>
  </div>
</template>

<style scoped>
/* Column layout: content grows, so the footer stays at the bottom even on short pages */
.site {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.site-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background: #fff;
  border-bottom: 1px solid #f0f0f0;
}

.site-header-inner {
  max-width: 800px;
  margin: 0 auto;
  padding: 12px 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.brand {
  font-size: 20px;
  font-weight: 700;
  color: #1677ff;
  text-decoration: none;
}

.site-content {
  flex: 1;
}

.site-footer {
  padding: 24px 16px;
  text-align: center;
  color: rgba(0, 0, 0, 0.45);
}
</style>
