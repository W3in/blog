// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  // Rails uses 3000, so Nuxt runs on 8000
  devServer: { port: 8000 },
  modules: ['@ant-design-vue/nuxt'],
  // Put Ant Design's CSS into the server HTML, otherwise pages flash unstyled until JS loads
  antd: { extractStyle: true },
  // Forward /api/* to Rails so the browser never calls another origin (no CORS setup needed)
  routeRules: {
    '/api/**': { proxy: 'http://localhost:3000/api/**' }
  },
  // Ant Design's reset first (removes browser default margins/fonts), then our own rules
  css: ['ant-design-vue/dist/reset.css', '~/assets/css/main.css'],
})
