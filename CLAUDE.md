# Blog — dự án học Rails + Nuxt

Người dùng đang **tự học** Rails 7.1 (API), Nuxt 3, Vue, Ant Design Vue và CSS qua dự án này.

## Cách làm việc với người dùng (quan trọng)

- **Trả lời bằng tiếng Việt.**
- **Mặc định: hướng dẫn, không sửa file.** Đưa code + giải thích để người dùng tự gõ. Người dùng từng khó chịu khi Claude tự sửa thứ họ muốn tự làm.
- **Chỉ sửa file khi được nhờ rõ ràng**: "làm giùm", "làm hết đi", "check và làm giùm", "làm nó đẹp hơn"... Khi sửa: chạy thử (curl / trình duyệt), rồi giải thích **từng thay đổi**: code cũ ↔ code mới, vì sao làm vậy, có cách khác không và vì sao không chọn.
- **Dòng đầu mỗi câu trả lời ghi rõ**: lượt này *đã sửa file* hay *chỉ hướng dẫn*. Từng có lần người dùng tưởng lượt hướng dẫn đã sửa code.
- Khi được nhờ giải thích "từng dòng" thì giải thích thật từng dòng, kể cả cú pháp JS/Ruby cơ bản (`?.`, `??`, `!!`, `::`, `@`, symbol...).
- Thử nghiệm không được làm hỏng dữ liệu thật; tạo user/bài test (email `zz-...@x.com`) rồi xóa sau khi thử.
- Không commit `config/master.key`, `.env`, database, log, `node_modules`. Commit/push chỉ khi người dùng bảo; repo dùng thẳng nhánh `main`.

## Cấu trúc & cách chạy

```
backend/   Rails 7.1 API, SQLite, Ruby 3.2.11 (cài qua mise)   → http://localhost:3000
frontend/  Nuxt 3 + Ant Design Vue 4 (@ant-design-vue/nuxt)    → http://localhost:8000
```

Máy mới:
```bash
cd backend && bundle install && bin/rails db:prepare && bin/rails s
cd frontend && npm install && npm run dev
```
Database không nằm trong git: máy mới sẽ trống, cần đăng ký user lại (qua trang `/register` hoặc `User.create!` trong `bin/rails c`). Cấp admin: `User.find_by(email: "...").update!(admin: true)`.

- Nuxt gọi Rails qua proxy `routeRules: { '/api/**': { proxy: 'http://localhost:3000/api/**' } }` trong `frontend/nuxt.config.ts` → cùng origin, không cần CORS.
- Ant Design: `antd: { extractStyle: true }` + `<AExtractStyle>` trong `app.vue` để SSR có CSS (tránh trang nháy). `a-select` phải có `id` cố định (tránh lỗi hydration).
- Giao diện HTML cũ của Rails (`/articles`, `.html.erb`) **đã xóa** (lộ bài `private`/`archived` cho khách, mật khẩu Basic Auth `dhh/secret` nằm trong code). Rails giờ chỉ là API dưới `/api`.
- Windows: chạy `ruby bin/rails s` (Windows không hiểu shebang); `config/puma.rb` tắt `plugin :tmp_restart` trên Windows (mtime lần đầu làm tròn giây → Puma tự restart rồi sập).
- Frontend: `middleware/auth.ts` (khách → `/login?redirect=...`), `middleware/guest.ts` (đã đăng nhập → `/`); `edit.vue` ném 403 nếu không phải tác giả. Chỉ để giao diện gọn, Rails vẫn chặn thật.

## Backend (Rails API)

- `app/controllers/api/base_controller.rb`: mọi controller API kế thừa. Có `current_user` (đọc `Authorization: Bearer <token>` bằng `authenticate_with_http_token`) và `require_login` (401).
- Đăng nhập bằng token: `User` có `has_secure_password` + `has_secure_token :auth_token`, cột `admin` (boolean, mặc định false).
  - `POST /api/registration` (UsersController#create) → `{ token, user }`; permit `name, email, password, password_confirmation` (**không** permit `admin`).
  - `POST /api/session` (đăng nhập, `User.authenticate_by`) → `{ token, user }`; `GET /api/session` → user hiện tại kèm `admin`; `DELETE /api/session` → `regenerate_auth_token` (đăng xuất).
- `Article::STATUSES = %w[public private archived]` (cột `status` mặc định `public`, NOT NULL). Concern `Visible` của Rails guide đã bỏ.
- `Article.visible_to(user)`: khách → chỉ `public`; admin → tất cả; thành viên → `public` + `private` + bài của mình (kể cả `archived`).
- `Comment`: **không có `status`** (đã xóa cột: comment theo quyền xem của bài), `validates :body, presence: true`. `User`: email phải đúng định dạng (`URI::MailTo::EMAIL_REGEXP`).
- Index trả bài mới nhất trước (`order(created_at: :desc)`).
- Lỗi validate trả `:unprocessable_content` (422; tên mới của `:unprocessable_entity` trong Rack 3).
- `ArticlesController`: `set_article` dùng `visible_to` → bài không được xem trả **404** (không lộ là bài tồn tại). Sửa bài: chỉ tác giả (403). Xóa bài: tác giả hoặc admin. JSON kèm tác giả qua `AUTHOR_JSON = { only: [:id, :name] }` — **không bao giờ** `include: :user` (lộ `auth_token`, `password_digest`); index dùng `.includes(:user)` tránh N+1.
- `CommentsController`: cần đăng nhập; bài phải qua `visible_to`; tên người comment lấy từ `current_user.name` (cột `commenter`); xóa comment: người viết comment hoặc admin (**tác giả bài không được xóa comment của người khác**).

### Bảng phân quyền

| Hành động | Khách | Thành viên | Tác giả bài | Admin |
|---|---|---|---|---|
| Xem `public` | ✅ | ✅ | ✅ | ✅ |
| Xem `private` | ❌ | ✅ | ✅ | ✅ |
| Xem `archived` | ❌ | ❌ | bài của mình | ✅ |
| Tạo bài | ❌ | ✅ | ✅ | ✅ |
| Sửa bài | ❌ | ❌ | ✅ | ❌ |
| Xóa bài | ❌ | ❌ | ✅ | ✅ |
| Comment | ❌ | ✅ | ✅ | ✅ |
| Xóa comment | ❌ | của mình | của mình | ✅ mọi comment |

### Test

`ruby bin/rails test` → 58 test (model + API), phủ đủ bảng phân quyền. Fixtures: `alice` (tác giả 3 bài: public/private/archived), `bob` (thành viên), `admin`; mật khẩu `password123`, token `alice-token`/`bob-token`/`admin-token`. Helper `auth(user)` trong `test_helper.rb` tạo header Bearer. Gemfile ghim `minitest < 6` (minitest 6 làm `bin/rails test` lỗi trên Rails 7.1). Windows chạy test tuần tự (không có `fork()`).

## Frontend (Nuxt)

- `composables/useAuth.ts`: `token` = `useCookie('token')` (cookie để SSR biết người dùng), `user` = `useState('user')`, `headers` (computed Bearer), `login / register / logout / fetchUser`. `fetchUser` chỉ xóa token khi Rails trả 401.
- `plugins/auth.server.ts`: chạy `fetchUser()` trên server mỗi lần tải trang; user xuống trình duyệt qua `useState`.
- Mọi lời gọi API phải gửi token: `useFetch(url, { headers })` (truyền ref) và `$fetch(url, { ..., headers: headers.value })` (truyền giá trị).
- `components/AuthCard.vue`: khung chung cho `pages/login.vue` và `pages/register.vue`.
- `utils/fieldState.ts`: đổi lỗi 422 của Rails thành props `validateStatus`/`help` của `a-form-item` (trả `{}` khi không lỗi để rules vẫn chạy). `utils/formatDate.ts`: `formatDate`, `formatDateTime` (vi-VN, múi giờ cố định `Asia/Ho_Chi_Minh` để server và trình duyệt in cùng giờ).
- `utils/articleStatus.ts`: `statusLabel` (Công khai / Thành viên / Lưu trữ), `statusColor`, `statusOptions` cho ô "Ai được xem". Trang chủ gắn tag cho bài không công khai.
- `layouts/default.vue`: header sticky (logo, New Article, menu người dùng `a-dropdown` có Đăng xuất; khách thấy Đăng nhập/Đăng ký). Dưới 576px ẩn chữ (`.hide-mobile`).
- `pages/articles/[id]/index.vue`: `isAuthor`, `canDestroyArticle`, `canDestroyComment(c)` — bản sao luật Rails, **chỉ để ẩn nút**; Rails vẫn chặn 403.
- Bài học CSS đã gặp: rule của Ant Design thường mạnh hơn (specificity) → đặt CSS lên class của mình, dùng `:style` hoặc prop có sẵn, thay vì `:deep(.ant-...)`.

## Tiến độ

Đã xong: chặng 1 (User, đăng ký, đăng nhập) → 2 (`current_user`, logout) → 3 (phân quyền backend) → 4.1–4.3 (useAuth, login/register, header) → 4.4 (gửi token mọi request) → 4.5 (ẩn/hiện nút theo quyền, bỏ ô Commenter, khách thấy lời mời đăng nhập) → hiện tác giả + "Sửa lần cuối" → 6 (route middleware) → xóa giao diện HTML cũ → dọn `status` (bỏ ở comment, mặc định `public` ở bài, nhãn tiếng Việt), validate body comment + định dạng email, bộ test 58 ca. Giải thích toàn bộ code: `docs/giai-thich-code.md`.

Tiếp theo:
1. **Quên mật khẩu**: `generates_token_for :password_reset` (Rails 7.1), ActionMailer (dev: xem email trong log), trang nhập email + trang đặt lại mật khẩu.
2. Có thể: API trả 401 khi gửi token sai ở trang công khai (hiện coi là khách; `GET /api/session` đã trả 401 nên frontend vẫn tự xóa cookie hỏng).
