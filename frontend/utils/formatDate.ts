// Fixed time zone: the server (SSR) and the browser must print the same time, wherever the server runs
const timeZone = 'Asia/Ho_Chi_Minh'

// "18/11/2026"
export const formatDate = (iso: string) => new Date(iso).toLocaleDateString('vi-VN', { timeZone })

// "14:05 20/11/2026": edits often happen on the same day as creation, so the time matters here
export const formatDateTime = (iso: string) =>
  new Date(iso).toLocaleString('vi-VN', { timeZone, hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit', year: 'numeric' })

// "5 phút trước", "hôm qua": for notifications. Only shown in the browser (inside the bell), so the
// server/browser clock difference cannot cause a hydration mismatch
const rtf = new Intl.RelativeTimeFormat('vi', { numeric: 'auto' })
export function timeAgo(iso: string) {
  const seconds = Math.round((new Date(iso).getTime() - Date.now()) / 1000) // negative: in the past
  const steps: [Intl.RelativeTimeFormatUnit, number][] = [['second', 60], ['minute', 60], ['hour', 24], ['day', 7], ['week', 4.35], ['month', 12]]
  let value = seconds
  for (const [unit, size] of steps) {
    if (Math.abs(value) < size) return rtf.format(Math.round(value), unit)
    value /= size
  }
  return rtf.format(Math.round(value), 'year')
}
