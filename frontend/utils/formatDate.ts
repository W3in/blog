// Fixed time zone: the server (SSR) and the browser must print the same time, wherever the server runs
const timeZone = 'Asia/Ho_Chi_Minh'

// "18/11/2026"
export const formatDate = (iso: string) => new Date(iso).toLocaleDateString('vi-VN', { timeZone })

// "14:05 20/11/2026": edits often happen on the same day as creation, so the time matters here
export const formatDateTime = (iso: string) =>
  new Date(iso).toLocaleString('vi-VN', { timeZone, hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit', year: 'numeric' })
