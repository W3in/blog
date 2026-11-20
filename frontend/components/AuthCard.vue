<script setup lang="ts">
defineProps<{ title: string; subtitle: string }>()
</script>

<template>
  <main class="auth-page">
    <a-card class="auth-card" :bordered="false">
      <div class="auth-head">
        <div class="auth-icon"><slot name="icon" /></div>
        <h1 class="auth-title">{{ title }}</h1>
        <p class="auth-subtitle">{{ subtitle }}</p>
      </div>

      <slot />

      <p class="auth-footer"><slot name="footer" /></p>
    </a-card>
  </main>
</template>

<style scoped>
/* Narrower than the 800px used by other pages: a login form looks odd when stretched */
.auth-page {
  max-width: 420px;
  padding-top: 48px;
}

.auth-card {
  border-radius: 12px;
  box-shadow: 0 6px 24px rgba(0, 0, 0, 0.06);
}

.auth-head {
  text-align: center;
  margin-bottom: 24px;
}

/* Round tinted badge behind the page icon */
.auth-icon {
  width: 56px;
  height: 56px;
  margin: 0 auto 12px;
  border-radius: 50%;
  background: #e6f4ff;
  color: #1677ff;
  font-size: 26px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.auth-title {
  margin: 0;
  font-size: 24px;
  font-weight: 600;
}

.auth-subtitle {
  margin: 4px 0 0;
  color: rgba(0, 0, 0, 0.45);
}

.auth-footer {
  margin: 16px 0 0;
  text-align: center;
  color: rgba(0, 0, 0, 0.45);
}
</style>
