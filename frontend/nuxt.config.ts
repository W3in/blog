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
    '/api/**': { proxy: `${process.env.API_URL ?? 'http://localhost:3000'}/api/**` }
  },
  // Ant Design's reset first (removes browser default margins/fonts), then our own rules.
  // Fonts for the editor's font menu, served from our own site (no request to Google); each file
  // has a Vietnamese subset and the browser only downloads the subsets a page actually uses
  css: [
    'ant-design-vue/dist/reset.css',
    '@fontsource/be-vietnam-pro/400.css', '@fontsource/be-vietnam-pro/600.css',
    '@fontsource/playfair-display/400.css', '@fontsource/playfair-display/700.css', '@fontsource/playfair-display/400-italic.css',
    '@fontsource/lora/400.css', '@fontsource/lora/700.css', '@fontsource/lora/400-italic.css',
    '@fontsource/dancing-script/600.css',
    '~/assets/css/main.css'
  ],
})
