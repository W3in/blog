<script setup lang="ts">
// One avatar everywhere: the uploaded image when there is one, otherwise the coloured first letter
defineProps<{
  name?: string | null
  src?: string | null
  size?: number | 'small' | 'default' | 'large'
}>()
</script>

<template>
  <a-avatar v-if="src" :src="src" :alt="name ?? ''" :size="size" class="user-avatar" />
  <a-avatar v-else :size="size" class="user-avatar" :style="{ backgroundColor: avatarColor(name) }">{{ initial(name) }}</a-avatar>
</template>

<style scoped>
/* flex: none keeps it round when the row around it gets narrow */
.user-avatar {
  flex: none;
}
</style>
