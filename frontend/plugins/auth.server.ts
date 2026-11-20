// .server: runs once per page load on the Nuxt server; the user then reaches the browser through useState
export default defineNuxtPlugin(async () => {
  await useAuth().fetchUser()
})
