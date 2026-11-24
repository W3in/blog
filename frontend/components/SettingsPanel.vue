<script setup lang="ts">
// One block of settings: title + description on top, content, and an optional grey footer for the buttons
// (the layout GitHub and Vercel use for their settings pages)
defineProps<{ title: string; description?: string; danger?: boolean }>()
</script>

<template>
  <section class="panel" :class="{ danger }">
    <header class="panel-head">
      <h2 class="panel-title">{{ title }}</h2>
      <p v-if="description" class="panel-desc">{{ description }}</p>
    </header>
    <div class="panel-body"><slot /></div>
    <!-- $slots.footer: draw the footer bar only when the page gives one -->
    <footer v-if="$slots.footer" class="panel-footer"><slot name="footer" /></footer>
  </section>
</template>

<style scoped>
.panel {
  overflow: hidden;
  margin-bottom: 16px;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  background: #fff;
}

.panel-head {
  padding: 20px 24px 0;
}

.panel-title {
  margin: 0;
  font-size: 17px;
  font-weight: 600;
}

.panel-desc {
  margin: 4px 0 0;
  color: rgba(0, 0, 0, 0.5);
  font-size: 13px;
}

.panel-body {
  padding: 20px 24px;
}

/* Buttons on the right of a light grey bar: clearly "the end of this block" */
.panel-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
  padding: 12px 24px;
  border-top: 1px solid #f0f0f0;
  background: #fafafa;
}

.panel.danger {
  border-color: #ffccc7;
}

.panel.danger .panel-title {
  color: #cf1322;
}

.panel.danger .panel-footer {
  border-top-color: #ffccc7;
  background: #fff7f6;
}

@media (max-width: 576px) {
  .panel-head {
    padding: 16px 16px 0;
  }

  .panel-body {
    padding: 16px;
  }

  .panel-footer {
    padding: 12px 16px;
  }
}
</style>
