# Blog — dự án học Rails + Nuxt

Người dùng đang **tự học** Rails 7.1 (API), Nuxt 3, Vue, Ant Design Vue và CSS qua dự án này.

## Cách làm việc với người dùng (quan trọng)

- **Trả lời bằng tiếng Việt.**
- **Mặc định: hướng dẫn, không sửa file.** Đưa code + giải thích để người dùng tự gõ. Người dùng từng khó chịu khi Claude tự sửa thứ họ muốn tự làm.
- **Chỉ sửa file khi được nhờ rõ ràng**: "làm giùm", "làm hết đi", "check và làm giùm", "làm nó đẹp hơn"... Khi sửa: chạy thử (curl / trình duyệt), rồi giải thích **từng thay đổi**: code cũ ↔ code mới, vì sao làm vậy, có cách khác không và vì sao không chọn.
- **Dòng đầu mỗi câu trả lời ghi rõ**: lượt này *đã sửa file* hay *chỉ hướng dẫn*. Từng có lần người dùng tưởng lượt hướng dẫn đã sửa code.
- Khi được nhờ giải thích "từng dòng" thì giải thích thật từng dòng, kể cả cú pháp JS/Ruby cơ bản (`?.`, `??`, `!!`, `::`, `@`, symbol...).
- Thử nghiệm không được làm hỏng dữ liệu thật; tạo user/bài test (email `zz-...@x.com`) rồi xóa sau khi thử.
- Không commit `config/master.key`, `.env`, database, log, `node_modules`. Commit/push chỉ khi người dùng bảo. Thường dùng thẳng nhánh `main`; khi người dùng bảo "chia nhánh" thì làm trên nhánh riêng (vd `feature/profile`), commit theo từng phần để họ xem, **không push, không merge** khi chưa được bảo.

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
- Quên mật khẩu: `User` có `generates_token_for :password_reset, expires_in: 15.minutes` (gắn `password_salt` → link chết sau khi đổi mật khẩu). `Api::PasswordsController`: `POST /api/password {email}` → luôn 202 (không lộ email), gửi `PasswordsMailer.reset` nếu có user; `PATCH /api/password {token, password, password_confirmation}` → 204 + `regenerate_auth_token` (đăng xuất mọi máy), token sai/hết hạn → 422 `{token: [...]}`. Dev: mail ghi vào `tmp/mails/<email>` (base64) và **link in ra terminal Rails** (`[dev] Link đặt lại mật khẩu...`). Link trỏ về `FRONTEND_URL` (mặc định `http://localhost:8000`).
- **Hồ sơ** (`Api::ProfilesController`, `resource :profile` số ít → không có id, chỉ sửa được của chính mình; mọi action trả `User#profile_json` = id, name, email, admin, created_at, avatar_url): `PATCH /api/profile {profile: {name}}` (chỉ permit `name`; tên 2–50 ký tự). `PATCH /api/profile/email {password_challenge, email}`. `DELETE /api/profile {password_challenge}` → 204, **xóa kiểu Reddit** (`User#soft_delete!`, cột `users.deleted_at`): bài + comment giữ lại, tên → `User::DELETED_NAME` "[đã xóa]" (cả cột `commenter` của comment cũ), email → `deleted-<id>@deleted.invalid` (email cũ đăng ký lại được), mật khẩu ngẫu nhiên, token mới, avatar purge, xóa thông báo của họ. `current_user` và `UsersController#show` bỏ qua user có `deleted_at`. `PUBLIC_JSON` có `deleted` (frontend không link tới trang của tài khoản đã xóa). Dùng `authenticate` (không phải password_challenge) để kiểm mật khẩu; sai → `errors.add(:password_challenge, :invalid)` 422. `PATCH /api/profile/password {password_challenge, password, password_confirmation}` → `{token}`: `password_challenge` của Rails 7.1 bắt đúng mật khẩu hiện tại (sai → **422** ở `password_challenge`, không dùng 401 vì frontend sẽ tưởng hết phiên); token mới được đặt **trong cùng lần `update`** (gọi `regenerate_auth_token` sau đó sẽ lưu lần hai và kiểm lại challenge với mật khẩu mới → lỗi) → mọi máy khác bị đăng xuất, máy đang dùng nhận token mới.
- **Trả lời bình luận** (nhánh `feature/social`): `comments.parent_id` (tự tham chiếu), `Comment belongs_to :parent / has_many :replies`; validate cha cùng bài và chưa bị xóa. `GET /api/articles/:id` gửi **danh sách phẳng** có `parent_id`, frontend dựng cây. Xóa comment = `Comment#remove!`: có trả lời thì làm rỗng (`deleted_at`, body `[đã xóa]`, JSON ẩn hết người viết/nội dung, `can_destroy: false`, không trả lời tiếp được), không có thì destroy. Không có @mention tự do: nút "Trả lời" điền sẵn `@Tên` (chỉ là chữ), thông báo dựa vào `parent_id`.
- **Tim**: bảng `likes` polymorphic (`likeable` = Article/Comment), unique index (user, likeable) — model **không** validates uniqueness vì `LikesController#create` dùng `create_or_find_by!` (idempotent); `likes_count` counter_cache trên articles/comments; bỏ tim bằng `destroy_all` (để counter_cache giảm). Routes `POST/DELETE /api/articles/:id/like` và `.../comments/:comment_id/like` (cùng `LikesController`, qua `visible_to`). JSON bài có `liked` (thành viên), comment có `likes_count`, `liked` (một query `pluck` + Set cho cả danh sách).
- **Thông báo**: bảng `notifications` (recipient, actor, kind `comment`/`reply`, comment, read_at). Tạo trong `Comment after_create_commit :notify_people`: comment gốc → tác giả bài, trả lời → người viết comment cha; không tự báo mình, không báo tài khoản đã xóa; ẩn danh → JSON `actor: nil`. `GET /api/notifications` → `{ unread_count, items (30 mới nhất) }`, `POST /api/notifications/read` → đánh dấu hết. Không báo khi có tim; không realtime.
- **Avatar**: `User has_one_attached :avatar`, `User#avatar_url` (link `/api/files/...`). `PUT /api/profile/avatar` (multipart `file`, ≤ 2MB) / `DELETE` → `profile_json` (`Api::AvatarsController`). Kiểm ảnh dùng chung `Api::BaseController#accepted_image_type(file, max)` (magic bytes, render 422 + trả nil) với `UploadsController`. **Không** dùng blob của `/api/uploads` làm avatar (đổi avatar sẽ purge blob → xóa ảnh trong bài người khác). Không có variant/libvips: frontend tự cắt 256×256 (`utils/squareImage.ts`). JSON công khai của user: `User::PUBLIC_JSON = { only: [:id, :name], methods: :avatar_url }` (thay `AUTHOR_JSON` cũ); thẻ bài `Article#card_json` (index + trang công khai). N+1: `includes(user: { avatar_attachment: :blob })`.
- **Hồ sơ công khai**: `GET /api/users/:id` (`UsersController#show`) → id, name, created_at, avatar_url + `articles` (lọc bằng `Article.visible_to(current_user)`), không có email; id sai → 404.
- **Thông báo lỗi tiếng Việt**: `config.i18n.default_locale = :vi`, `fallbacks = [:en]` (application.rb; đã bỏ `fallbacks = true` ở production.rb vì nó ghi đè), `config/locales/vi.yml` (blank, taken, invalid, too_short...; `password_challenge.invalid` = "không đúng"). Token đặt lại mật khẩu gắn `[password_salt, email]` → chết cả khi đổi email.
- **Đổi tên & bình luận cũ**: `commenter` là tên lúc viết (giữ nguyên), `as_json_for` gửi thêm `current_name` (tên hiện tại, `nil` nếu ẩn danh); `show` dùng `comments.includes(:user)` tránh N+1. Frontend hiện tên cũ, gạch chấm, tooltip "Hiện tên là ..." khi khác nhau (hover/click/focus, có `tabindex` cho điện thoại và bàn phím).
- `Article::STATUSES = %w[public private archived]` (cột `status` mặc định `public`, NOT NULL). Concern `Visible` của Rails guide đã bỏ.
- `Article.visible_to(user)`: khách → chỉ `public`; admin → tất cả; thành viên → `public` + `private` + bài của mình (kể cả `archived`).
- `Comment`: **không có `status`** (đã xóa cột: comment theo quyền xem của bài), `validates :body, presence: true`, `belongs_to :article, counter_cache: true` (cột `articles.comments_count`). `User`: email phải đúng định dạng (`URI::MailTo::EMAIL_REGEXP`).
- **Comment ẩn danh**: cột `comments.anonymous`. `Comment#as_json_for(viewer)` là JSON duy nhất của comment: ẩn danh thì `commenter` và `user_id` = `nil` với **mọi người, kể cả admin** (DB vẫn giữ `user_id` để người viết/admin xóa được); kèm `can_destroy` do Rails tính.
- **Nội dung bài là HTML** (trình soạn TipTap). `Article` lọc HTML trước khi lưu (`before_validation :sanitize_body`): Rails `sanitize` giữ `ALLOWED_TAGS`/`ALLOWED_ATTRIBUTES` (có `span`, `style`, `width`/`height` của ảnh), rồi trong `style` chỉ giữ `ALLOWED_CSS` = màu chữ, màu nền, font, căn lề → frontend hiện bằng `v-html` an toàn. Body cần ≥ 10 ký tự **chữ** (`plain_text`, không đếm thẻ). Tiêu đề tối đa `TITLE_MAX = 300`. Migration `ConvertArticleBodiesToHtml` đã đổi bài cũ (chữ thường) sang `<p>`.
- **Bài mẫu**: `bin/rails demo:articles` (`lib/tasks/demo.rake`, chọn tác giả bằng `EMAIL=...`, mặc định admin đầu tiên rồi user đầu tiên; chạy lại thì bỏ qua bài đã có) tạo 3 bài: bài dài công khai (khách chỉ thấy phần đầu), bài tiêu đề đúng 300 ký tự, bài du lịch Đà Lạt có 4 ảnh minh họa (`db/demo/*.jpg`, vẽ bằng code, không vướng bản quyền) + font/màu/tô nền/căn giữa.
- **Khách chỉ đọc phần đầu**: `GET /api/articles/:id` cho khách → `body` = `Article#preview` (các khối đầu tới ~300 ký tự, không cắt giữa thẻ), `truncated`, **không có `comments`** (chỉ `comments_count`). Index **không gửi `body`**: chỉ `excerpt` (chữ thường 200 ký tự) + `cover_image` (ảnh đầu tiên).
- **Ảnh**: `POST /api/uploads` (cần đăng nhập, `UploadsController`) nhận PNG/JPG/GIF/WebP ≤ 5MB, kiểm tra loại file bằng byte đầu (Marcel), trả `{ url }`. Active Storage: `routes_prefix = "/api/files"` + `resolve_model_to_route = :rails_storage_proxy` (Rails tự gửi file, đi qua proxy Nuxt có sẵn). File nằm trong `storage/` (Docker: volume `db`). Ảnh tải lên mà không dùng thì vẫn nằm trên đĩa (chưa có job dọn).
- Index trả bài mới nhất trước (`order(created_at: :desc)`).
- Lỗi validate trả `:unprocessable_content` (422; tên mới của `:unprocessable_entity` trong Rack 3).
- `ArticlesController`: `set_article` dùng `visible_to` → bài không được xem trả **404** (không lộ là bài tồn tại). Sửa bài: chỉ tác giả (403). Xóa bài: tác giả hoặc admin. JSON kèm tác giả qua `AUTHOR_JSON = { only: [:id, :name] }` — **không bao giờ** `include: :user` (lộ `auth_token`, `password_digest`); index dùng `.includes(:user)` tránh N+1.
- `CommentsController`: cần đăng nhập; bài phải qua `visible_to`; tên người comment lấy từ `current_user.name` (cột `commenter`); xóa comment: người viết comment hoặc admin (**tác giả bài không được xóa comment của người khác**).

### Bảng phân quyền

| Hành động | Khách | Thành viên | Tác giả bài | Admin |
|---|---|---|---|---|
| Xem `public` | phần đầu, không thấy comment | ✅ | ✅ | ✅ |
| Xem `private` | ❌ | ✅ | ✅ | ✅ |
| Xem `archived` | ❌ | ❌ | bài của mình | ✅ |
| Tạo bài | ❌ | ✅ | ✅ | ✅ |
| Sửa bài | ❌ | ❌ | ✅ | ❌ |
| Xóa bài | ❌ | ❌ | ✅ | ✅ |
| Comment (có thể ẩn danh) | ❌ | ✅ | ✅ | ✅ |
| Tải ảnh lên | ❌ | ✅ | ✅ | ✅ |
| Xóa comment | ❌ | của mình | của mình | ✅ mọi comment |

### Test

`ruby bin/rails test` → 123 test (model + API), phủ đủ bảng phân quyền, ẩn danh, hồ sơ (đổi tên, mật khẩu, email, avatar, xóa tài khoản kiểu Reddit, trang công khai), trả lời/tim/thông báo (`social_test.rb`), bản xem trước, lọc HTML, upload (ảnh mẫu `test/fixtures/files/pixel.png`, file giả `fake.png`). Fixtures: `alice` (tác giả 3 bài: public/private/archived), `bob` (thành viên), `admin`; mật khẩu `password123`, token `alice-token`/`bob-token`/`admin-token`. Helper `auth(user)` trong `test_helper.rb` tạo header Bearer. Gemfile ghim `minitest < 6` (minitest 6 làm `bin/rails test` lỗi trên Rails 7.1). Windows chạy test tuần tự (không có `fork()`).

## Frontend (Nuxt)

- `composables/useAuth.ts`: `token` = `useCookie('token')` (cookie để SSR biết người dùng), `user` = `useState('user')`, `headers` (computed Bearer), `login / register / logout / fetchUser`. `fetchUser` chỉ xóa token khi Rails trả 401.
- `plugins/auth.server.ts`: chạy `fetchUser()` trên server mỗi lần tải trang; user xuống trình duyệt qua `useState`.
- Mọi lời gọi API phải gửi token: `useFetch(url, { headers })` (truyền ref) và `$fetch(url, { ..., headers: headers.value })` (truyền giá trị).
- `components/AuthCard.vue`: khung chung cho `pages/login.vue`, `register.vue`, `forgot-password.vue`, `reset-password.vue` (cả 4 dùng middleware `guest`). Login có link "Quên mật khẩu?" và hiện thông báo xanh khi `?reset=1`.
- `utils/fieldState.ts`: đổi lỗi 422 của Rails thành props `validateStatus`/`help` của `a-form-item` (trả `{}` khi không lỗi để rules vẫn chạy). `utils/formatDate.ts`: `formatDate`, `formatDateTime` (vi-VN, múi giờ cố định `Asia/Ho_Chi_Minh` để server và trình duyệt in cùng giờ).
- `utils/articleStatus.ts`: `statusLabel` (Công khai / Thành viên / Lưu trữ), `statusColor`, `statusOptions` cho ô "Ai được xem". Trang chủ gắn tag cho bài không công khai.
- **Trang hồ sơ = route lồng nhau**: `pages/profile.vue` là khung cha (middleware `auth` áp cho cả con; `ProfileHeader` + menu trái bằng 4 `NuxtLink` viết tường minh — icon Ant chỉ được import khi tên thẻ có trong template, `resolveComponent` với tên trong biến không chạy; mục đang mở tô theo `[aria-current='page']`; grid `230px minmax(0, 1fr)`, dưới 720px thành 1 cột + menu chip cuộn ngang) + `<NuxtPage />`; mỗi mục con là `<a-form>` bọc `SettingsPanel` (tiêu đề, mô tả, slot `footer` = thanh nút xám); con: `pages/profile/index.vue` (avatar: input file ẩn → `squareImage` → `FormData` PUT; tên), `email.vue`, `password.vue` (lưu xong gán `token.value` = token mới), `delete.vue` (mật khẩu + ô xác nhận; xong thì xóa token/user, về `/`). Lưu xong gán `user.value` = JSON Rails trả để header đổi ngay.
- `pages/users/[id].vue`: trang công khai (`ProfileHeader`: bìa màu theo `avatarColor`, avatar, ngày tham gia, số bài, nút "Chỉnh sửa hồ sơ" nếu là mình; danh sách `ArticleCard`).
- **Bình luận**: `components/CommentThread.vue` đệ quy (đọc `inject('thread')` = `{ articleId, childrenOf, refresh }` do trang bài `provide`; kiểu ở `types/comment.ts`), thụt lề tới cấp 3 rồi `.flat`; đường dọc dưới avatar là nút thu gọn, thu gọn hiện "+ N trả lời"; tô vàng comment khi `route.hash === '#comment-<id>'` (không dùng `:target` vì pushState không cập nhật nó). `CommentComposer.vue` (ô soạn dùng cho bình luận gốc và trả lời, emit `posted`/`cancel`, focus + con trỏ sau `@Tên `). `LikeButton.vue` (optimistic, khách → login). `NotificationBell.vue` trong header + `composables/useNotifications.ts` (useState, polling 30 s + mỗi lần đổi trang, mở chuông = đánh dấu đã đọc, mục → `/articles/:id#comment-:id`), `timeAgo` (Intl.RelativeTimeFormat, chỉ dùng phía trình duyệt). Tên tác giả ở trang bài là link tới đây.
- `components/UserAvatar.vue` (ảnh nếu có `src`, không thì chữ cái đầu + `avatarColor`) dùng ở header, thẻ bài, trang bài, bình luận, hồ sơ. `components/ArticleCard.vue` (thẻ bài, tách từ `index.vue`) + kiểu `types/article.ts` (`import type`). `.feed` ở `main.css`.
- **Giao diện toàn tiếng Việt**: tên trang "Blog của tôi" (header, footer, `app.head.title`, email đặt lại mật khẩu), `<html lang="vi">` (`nuxt.config.ts` → `app.head.htmlAttrs`), chữ có sẵn của Ant Design qua `<a-config-provider :locale="viVN">` (`ant-design-vue/es/locale/vi_VN`) trong `app.vue`. `error.vue`: trang lỗi 404/403/500 tiếng Việt, tự bọc `AExtractStyle` + config-provider (vì error.vue thay hẳn app.vue). Nhãn trong `fieldState(...)` cũng tiếng Việt ("Mật khẩu", "Tiêu đề"...).
- `layouts/default.vue`: header sticky (logo, nút "Viết bài", chuông thông báo (`BellFilled` đỏ + rung khi có chưa đọc, badge đỏ số lượng), menu người dùng `a-dropdown` có Trang cá nhân, Hồ sơ của tôi, Đăng xuất; khách thấy Đăng nhập/Đăng ký). Dưới 576px ẩn chữ (`.hide-mobile`).
- Giao diện kiểu Reddit: trang chủ là danh sách thẻ bài (tác giả, ngày, tiêu đề, trích đoạn, ảnh nhỏ, số bình luận); `utils/avatarColor.ts` (`avatarColor`, `initial`: màu avatar cố định theo tên). CSS chung trong `assets/css/main.css`: `.rich-content` (kiểu chữ cho HTML bài viết, global vì `v-html` không nhận scoped CSS), `.pill`, `.muted`.
- `components/RichEditor.vue`: trình soạn TipTap 3.33.0 (ghim phiên bản, mọi gói `@tiptap/*` cùng bản) — đậm/nghiêng/gạch, **font** (5 kiểu), **màu chữ**, **tô nền**, H2/H3, **căn trái/giữa/phải**, danh sách, trích dẫn, code, link, ảnh, hoàn tác; `v-model` là HTML. Ảnh: nút chọn file, **dán (Ctrl+V) hoặc kéo thả** (`FileHandler`), mới chèn thì rộng tối đa 640px; chọn ảnh rồi **kéo 4 góc** (Image `resize`) hoặc bấm Nhỏ/Vừa/Tràn (240/420/bằng cột). Thanh công cụ có `@mousedown.prevent` (không thì bấm nút làm mất con trỏ, chữ gõ rơi ra ngoài danh sách). `ArticleForm.vue` dùng nó.
- Font tự host bằng `@fontsource/*` 5.3.0 (Be Vietnam Pro, Playfair Display, Lora, Dancing Script; có bộ chữ tiếng Việt), nạp trong `css` của `nuxt.config.ts` — không gọi Google Fonts.
- `pages/articles/[id]/index.vue`: `isAuthor`, `canDestroyArticle` — bản sao luật Rails, **chỉ để ẩn nút**; nút xóa comment theo `c.can_destroy` từ Rails. Khách: nội dung mờ dần + khung "Đăng nhập để đọc tiếp". Thành viên: ô bình luận kiểu Reddit có ô "Ẩn danh" (Ctrl+Enter để gửi).
- Bài học CSS đã gặp: rule của Ant Design thường mạnh hơn (specificity) → đặt CSS lên class của mình, dùng `:style` hoặc prop có sẵn, thay vì `:deep(.ant-...)`.

## Tiến độ

Đã xong: chặng 1 (User, đăng ký, đăng nhập) → 2 (`current_user`, logout) → 3 (phân quyền backend) → 4.1–4.3 (useAuth, login/register, header) → 4.4 (gửi token mọi request) → 4.5 (ẩn/hiện nút theo quyền, bỏ ô Commenter, khách thấy lời mời đăng nhập) → hiện tác giả + "Sửa lần cuối" → 6 (route middleware) → xóa giao diện HTML cũ → dọn `status` (bỏ ở comment, mặc định `public` ở bài, nhãn tiếng Việt), validate body comment + định dạng email → quên mật khẩu → Docker (`docker-compose.yml`, `frontend/Dockerfile`, GitHub Actions đẩy image lên GHCR) → giao diện kiểu Reddit + trình soạn có ảnh + khách đọc phần đầu + comment ẩn danh → font/màu/căn lề, kéo đổi cỡ ảnh, dán ảnh, bài mẫu `demo:articles`. → hồ sơ (nhánh `feature/profile` → `feature/social`, đã merge vào `main`): đổi tên (bình luận cũ giữ tên cũ + tooltip tên hiện tại), đổi mật khẩu, đổi email, avatar, xóa tài khoản, trang công khai `/users/:id`, lỗi tiếng Việt. → xóa tài khoản kiểu Reddit, giao diện hồ sơ mới, trả lời lồng nhau, tim, thông báo. Bộ test 123 ca. Giải thích: `docs/parts/11-ho-so.md`, `docs/parts/12-tuong-tac.md`. Giải thích toàn bộ code: `docs/giai-thich-code.md` (chỉ ở máy, `docs/` bị gitignore).

Tiếp theo (có thể): xác nhận email mới bằng link, tự chọn vùng cắt avatar. API trả 401 khi gửi token sai ở trang công khai (hiện coi là khách; `GET /api/session` đã trả 401 nên frontend vẫn tự xóa cookie hỏng).
