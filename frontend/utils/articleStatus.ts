// Same three values as Article::STATUSES in Rails; labels say who can read the article
export const statusLabel: Record<string, string> = {
  public: 'Công khai',
  private: 'Thành viên',
  archived: 'Lưu trữ'
}

export const statusColor: Record<string, string> = { public: 'green', private: 'orange', archived: 'default' }

export const statusOptions = [
  { value: 'public', label: 'Công khai' },
  { value: 'private', label: 'Thành viên' },
  { value: 'archived', label: 'Lưu trữ' }
]
