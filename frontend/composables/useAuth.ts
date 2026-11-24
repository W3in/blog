type User = { id: number; name: string; email: string; admin: boolean; created_at: string; avatar_url: string | null }

export function useAuth() {
    // Cookie (not localStorage) so the server-side render also knows who is logged in
    const token = useCookie<string | null>('token', { maxAge: 60 * 60 * 24 * 30, sameSite: 'lax' })
    // useState: one shared value for every component, passed from server to browser
    const user = useState<User | null>('user', () => null)

    const headers = computed(() => (token.value ? { Authorization: `Bearer ${token.value}` } : {}))

    async function fetchUser() {
        if (!token.value) return (user.value = null)
        try {
            user.value = await $fetch<User>('/api/session', { headers: headers.value })
        } catch (e: any) {
            if (e.status === 401) token.value = null
            user.value = null
        }
    }

    async function login(email: string, password: string) {
        const res = await $fetch<{ token: string }>('/api/session', { method: 'POST', body: { email, password } })
        token.value = res.token
        await fetchUser() // GET /api/session also tells us whether this user is admin
    }

    async function register(form: { name: string; email: string; password: string; password_confirmation: string }) {
        const res = await $fetch<{ token: string }>('/api/registration', { method: 'POST', body: { user: form } })
        token.value = res.token
        await fetchUser()
    }

    async function logout() {
        await $fetch('/api/session', { method: 'DELETE', headers: headers.value }).catch(() => { })
        token.value = null
        user.value = null
        await navigateTo('/')
    }

    return { user, token, headers, login, register, logout, fetchUser }
}