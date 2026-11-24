<script setup lang="ts">
// Cover + big avatar + name, shared by the settings page (/profile) and the public page (/users/:id)
const props = defineProps<{ name: string; avatarUrl?: string | null }>()

// The cover takes the colour of the avatar letter, so each person's page looks a little different
const coverStyle = computed(() => {
  const c = avatarColor(props.name)
  // Colour #rrggbb + 2 hex digits = transparency (aa ≈ 67%, 22 ≈ 13%): soft, so a red name does not look like an error
  return { background: `radial-gradient(circle at 85% 20%, #ffffff66 0 56px, transparent 57px), linear-gradient(120deg, ${c}aa, ${c}22)` }
})
</script>

<template>
  <section class="profile-header">
    <div class="cover" :style="coverStyle" />
    <div class="header-body">
      <UserAvatar :name="name" :src="avatarUrl" :size="104" class="header-avatar" />
      <div class="header-info">
        <h1 class="header-name">{{ name }}</h1>
        <div class="header-meta"><slot name="meta" /></div>
      </div>
      <div class="header-actions"><slot name="actions" /></div>
    </div>
  </section>
</template>

<style scoped>
.profile-header {
  overflow: hidden; /* keeps the cover inside the rounded corners */
  margin-bottom: 20px;
  border: 1px solid #f0f0f0;
  border-radius: 16px;
  background: #fff;
}

.cover {
  height: 120px;
}

.header-body {
  display: flex;
  align-items: flex-end;
  flex-wrap: wrap;
  gap: 16px;
  padding: 0 24px 20px;
}

/* Pulled up so half of it sits on the cover; the white ring separates it from the colour */
.header-avatar {
  margin-top: -52px;
  border: 4px solid #fff;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
}

.header-info {
  flex: 1;
  min-width: 0;
}

.header-name {
  margin: 0;
  font-size: 24px;
  font-weight: 700;
  line-height: 1.3;
  overflow-wrap: anywhere;
}

.header-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 12px;
  margin-top: 2px;
  color: rgba(0, 0, 0, 0.5);
  font-size: 13px;
}

@media (max-width: 576px) {
  .cover {
    height: 88px;
  }

  .header-body {
    padding: 0 16px 16px;
  }

  .header-actions {
    width: 100%;
  }
}
</style>
