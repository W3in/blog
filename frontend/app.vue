<script setup lang="ts">
// Ant Design's built-in texts (popconfirm buttons, "No data", ...) in Vietnamese
import viVN from 'ant-design-vue/es/locale/vi_VN'
</script>

<template>
  <div>
    <NuxtRouteAnnouncer />
    <!-- Collects the Ant Design CSS used while rendering on the server (enabled by antd.extractStyle) -->
    <AExtractStyle>
      <a-config-provider :locale="viVN">
        <NuxtLayout>
          <NuxtPage />
        </NuxtLayout>
      </a-config-provider>
    </AExtractStyle>
  </div>
</template>
