// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  // Rails uses 3000, so Nuxt runs on 8000
  devServer: { port: 8000 },
  modules: ['@ant-design-vue/nuxt'],
  // Forward /api/* to Rails so the browser never calls another origin (no CORS setup needed)
  routeRules: {
    '/api/**': { proxy: 'http://localhost:3000/api/**' }
  }
})
