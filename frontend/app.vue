<template>
  <div>
    <NuxtRouteAnnouncer />
    <!-- Collects the Ant Design CSS used while rendering on the server (enabled by antd.extractStyle) -->
    <AExtractStyle>
      <NuxtLayout>
        <NuxtPage />
      </NuxtLayout>
    </AExtractStyle>
  </div>
</template>
