// "18/11/2026"
export const formatDate = (iso: string) => new Date(iso).toLocaleDateString('vi-VN')

// "14:05 20/11/2026": edits often happen on the same day as creation, so the time matters here
export const formatDateTime = (iso: string) =>
  new Date(iso).toLocaleString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit', year: 'numeric' })
