# Giải thích toàn bộ code dự án Blog

Tài liệu này đi qua **từng file** của dự án, theo thứ tự một request chạy qua hệ thống: database → Rails → Nuxt → trình duyệt. Cuối tài liệu có kịch bản demo và các câu hỏi hay gặp.

> Quy ước: `code` là tên trong code; **(cú pháp)** là phần giải thích cú pháp Ruby/JS cơ bản.

## Mục lục

1. [Bức tranh tổng thể](#1-bức-tranh-tổng-thể)
2. [Database](#2-database)
3. [Backend Rails](#3-backend-rails)
4. [Frontend Nuxt](#4-frontend-nuxt)
5. [Các luồng hoàn chỉnh từ đầu đến cuối](#5-các-luồng-hoàn-chỉnh-từ-đầu-đến-cuối)
6. [Bảo mật: những gì đã được bảo vệ](#6-bảo-mật-những-gì-đã-được-bảo-vệ)
7. [Test](#7-test)
8. [Những gì đã sửa trong đợt dọn dẹp cuối](#8-những-gì-đã-sửa-trong-đợt-dọn-dẹp-cuối)
9. [Kịch bản demo và câu hỏi hay gặp](#9-kịch-bản-demo-và-câu-hỏi-hay-gặp)
10. [Giới hạn và việc còn lại](#10-giới-hạn-và-việc-còn-lại)

---

## 1. Bức tranh tổng thể

### 1.1 Hai chương trình chạy song song

```
                 cổng 8000                                cổng 3000
Trình duyệt ───► Nuxt (Vue, Ant Design) ──/api/**──► Rails API ───► SQLite
   ▲                 │  (proxy)                         │           (file .sqlite3)
   └──── HTML + JS ──┘                                  └── JSON ──┘
```

- **Rails** (thư mục `backend/`) chỉ làm **API**: nhận request, kiểm tra quyền, đọc/ghi database, trả **JSON**. Rails không vẽ giao diện.
- **Nuxt** (thư mục `frontend/`) làm **giao diện**: vẽ trang bằng Vue + Ant Design, gọi API của Rails để lấy dữ liệu.
- Trình duyệt **chỉ nói chuyện với cổng 8000**. Mọi đường dẫn bắt đầu bằng `/api/` được Nuxt chuyển tiếp (proxy) sang Rails. Vì cùng một địa chỉ (cùng *origin*), không cần cấu hình CORS.

### 1.2 SSR là gì và vì sao quan trọng ở đây

Nuxt chạy **SSR (Server-Side Rendering)**: khi bạn mở hoặc F5 một trang, chính **server Nuxt** gọi API, dựng sẵn HTML đầy đủ rồi gửi cho trình duyệt. Sau đó JavaScript trong trình duyệt "tiếp quản" trang đó (gọi là **hydration**) để các nút bấm hoạt động.

Hệ quả: code trong `<script setup>` của một trang **có thể chạy 2 nơi**: trên server Nuxt (lúc F5) và trong trình duyệt (lúc bấm link chuyển trang). Đó là lý do:
- token được lưu trong **cookie** (server đọc được) chứ không phải `localStorage` (chỉ trình duyệt đọc được);
- ngày giờ phải cố định múi giờ, nếu không server và trình duyệt in ra hai giờ khác nhau.

### 1.3 Đăng nhập bằng token

1. Người dùng đăng nhập → Rails kiểm tra mật khẩu → trả về một chuỗi bí mật ngẫu nhiên gọi là **token** (lưu ở cột `users.auth_token`).
2. Nuxt cất token vào cookie `token`.
3. Mọi request sau đó gửi kèm header `Authorization: Bearer <token>`.
4. Rails tìm user có `auth_token` đó → biết ai đang gọi.
5. Đăng xuất → Rails **đổi token mới** (`regenerate_auth_token`) → token cũ vô hiệu ngay lập tức.

### 1.4 Hai lớp phân quyền

| Lớp | Ở đâu | Mục đích | Có thể bị vượt qua? |
|---|---|---|---|
| Backend | `before_action`, `visible_to`, `head :forbidden` trong Rails | **Bảo mật thật**: chặn dữ liệu | Không |
| Frontend | `middleware/*.ts`, ẩn/hiện nút, 403 ở trang sửa | **Trải nghiệm**: không cho người dùng vào trang/bấm nút vô nghĩa | Có (gọi thẳng API bằng curl), nhưng không sao vì backend vẫn chặn |

Câu tóm tắt khi demo: **"Backend chặn thật, frontend chỉ làm giao diện gọn."**

### 1.5 Cách chạy (Windows)

```powershell
cd backend
ruby bin/rails db:prepare      # lần đầu: tạo database theo db/schema.rb
ruby bin/rails s               # Rails ở http://localhost:3000
```

```powershell
cd frontend
npm install                    # lần đầu
npm run dev                    # Nuxt ở http://localhost:8000
```

Trên Windows phải gõ `ruby bin/rails ...` vì `bin/rails` là file Ruby có dòng đầu `#!/usr/bin/env ruby` (gọi là *shebang*), Windows không hiểu dòng này.

---

## 2. Database

### 2.1 Ba bảng và quan hệ

```
users                        articles                       comments
─────────────                ─────────────                  ─────────────
id                           id                             id
name                         title                          body
email (unique)               body                           commenter   (tên người viết, chép từ users.name)
password_digest              status  (public/private/       article_id ──► articles.id
auth_token (unique)                   archived, mặc định    user_id    ──► users.id
admin (true/false)                    public, NOT NULL)     created_at, updated_at
created_at, updated_at       user_id ──► users.id
                             created_at, updated_at
```

- Một **user** có nhiều **article** và nhiều **comment**.
- Một **article** thuộc về một user (tác giả) và có nhiều comment.
- Một **comment** thuộc về một article và một user.

### 2.2 `db/schema.rb`

File này **Rails tự sinh** sau mỗi lần chạy migration. Nó mô tả cấu trúc database hiện tại. Không sửa tay. Máy mới chạy `db:prepare` sẽ tạo database từ file này.

Các chi tiết đáng chú ý:
- `t.index ["email"], unique: true` và `t.index ["auth_token"], unique: true`: database **tự chặn** 2 user trùng email hoặc trùng token, kể cả khi code Rails có lỗi.
- `t.boolean "admin", default: false, null: false`: user mới luôn không phải admin.
- `t.string "status", default: "public", null: false`: bài viết không gửi status sẽ là `public`.
- `add_foreign_key "comments", "articles"`: database không cho tồn tại comment trỏ tới bài không có thật.

### 2.3 Migrations (`db/migrate/`)

Mỗi migration là **một bước thay đổi** database, có số thời gian ở đầu tên để Rails chạy đúng thứ tự:

| File | Làm gì |
|---|---|
| `..._create_articles.rb` | Tạo bảng `articles` (title, body) |
| `..._create_comments.rb` | Tạo bảng `comments` (commenter, body, article_id) |
| `..._add_status_to_articles.rb` | Thêm cột `status` cho bài (từ Rails guide) |
| `..._add_status_to_comments.rb` | Thêm cột `status` cho comment (từ Rails guide) |
| `..._create_users.rb` | Tạo bảng `users` + 2 index unique |
| `..._add_user_to_articles.rb` | Thêm `user_id` cho bài |
| `..._add_user_to_comments.rb` | Thêm `user_id` cho comment |
| `..._clean_up_status_columns.rb` | **Mới**: status bài mặc định `public` + NOT NULL; **xóa** `status` của comment |

Migration mới nhất:

```ruby
class CleanUpStatusColumns < ActiveRecord::Migration[7.1]
  def change
    change_column_default :articles, :status, from: nil, to: "public"
    change_column_null :articles, :status, false, "public"
    remove_column :comments, :status, :string
  end
end
```

- `class CleanUpStatusColumns < ActiveRecord::Migration[7.1]`: **(cú pháp)** `<` nghĩa là "kế thừa từ". `[7.1]` cho biết migration viết theo luật của Rails 7.1.
- `def change ... end`: Rails tự biết cách **chạy ngược** (rollback) các lệnh trong `change`. Mình đã thử `db:rollback` rồi `db:migrate` lại, cả hai chiều đều chạy.
- `change_column_default ..., from: nil, to: "public"`: đổi giá trị mặc định. Ghi cả `from` để Rails biết chạy ngược thì trả về `nil`.
- `change_column_null :articles, :status, false, "public"`: cấm NULL. Tham số thứ 4 `"public"` nghĩa là: **những dòng đang NULL thì điền `"public"`** trước khi cấm (nếu không, lệnh sẽ lỗi vì có dữ liệu vi phạm).
- `remove_column :comments, :status, :string`: xóa cột. Ghi kiểu `:string` để chạy ngược thì Rails biết tạo lại cột kiểu gì.

**(cú pháp)** `:articles`, `:status` là **symbol**: một tên cố định, giống chuỗi nhưng nhẹ hơn và dùng làm "nhãn". `:status` khác `"status"` về kiểu, nhưng Rails nhận cả hai ở hầu hết chỗ.

---

## 3. Backend Rails

### 3.1 `config/routes.rb`: bảng chỉ đường

```ruby
Rails.application.routes.draw do
  namespace :api do
    resource :registration, only: :create, controller: "users" # POST /api/registration
    resource :session, only: [:create, :show, :destroy]         # POST /api/session

    resources :articles, only: [:index, :show, :create, :update, :destroy] do
      resources :comments, only: [:create, :destroy]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- `routes.rb` quyết định **URL nào chạy vào controller/action nào**. URL không có ở đây → 404, không chạy dòng code nào.
- `namespace :api do ... end`: mọi route bên trong có tiền tố `/api` và controller nằm trong module `Api` (thư mục `app/controllers/api/`).
- `resource :registration` (số ít, không có "s"): tài nguyên **chỉ có một** (bạn chỉ có một "lần đăng ký"), nên URL **không có `:id`**. `only: :create` → chỉ sinh `POST /api/registration`. `controller: "users"` → chạy vào `Api::UsersController` thay vì `RegistrationsController`.
- `resource :session` (số ít): mỗi người chỉ có một phiên đăng nhập.
  - `create` → `POST /api/session` (đăng nhập)
  - `show` → `GET /api/session` (tôi là ai?)
  - `destroy` → `DELETE /api/session` (đăng xuất)
- `resources :articles` (số nhiều): có nhiều bài, nên URL có `:id`.
  - `index` → `GET /api/articles`
  - `show` → `GET /api/articles/:id`
  - `create` → `POST /api/articles`
  - `update` → `PATCH /api/articles/:id` (và `PUT`)
  - `destroy` → `DELETE /api/articles/:id`
- `resources :comments` **lồng** trong articles → URL dạng `/api/articles/:article_id/comments` và `/api/articles/:article_id/comments/:id`. Lồng như vậy để comment luôn gắn với một bài.
- `get "up" => "rails/health#show"`: trả 200 nếu server sống; dùng khi deploy.

Xem toàn bộ route: `ruby bin/rails routes`.

### 3.2 Model `User` (`app/models/user.rb`)

```ruby
class User < ApplicationRecord
    has_secure_password
    has_secure_token :auth_token

    has_many :articles, dependent: :destroy
    has_many :comments, dependent: :destroy

    normalizes :email, with: ->(e) { e.strip.downcase }
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :name, presence: true
    validates :password, presence: true, length: { minimum: 6 }, allow_nil: true
end
```

- `class User < ApplicationRecord`: model `User` ứng với bảng `users`. `ApplicationRecord` cho nó mọi khả năng đọc/ghi database (`User.find`, `user.save`...).
- `has_secure_password` (cần gem `bcrypt`): thêm cho model
  - 2 thuộc tính "ảo" `password` và `password_confirmation` (không có cột trong DB);
  - khi lưu, mã hóa `password` bằng bcrypt rồi ghi vào cột `password_digest`. **Database không bao giờ chứa mật khẩu thật**;
  - kiểm tra `password` khớp `password_confirmation`, bắt buộc có mật khẩu khi tạo mới, tối đa 72 byte;
  - hàm `User.authenticate_by(email:, password:)` dùng ở trang đăng nhập.
- `has_secure_token :auth_token`: khi tạo user, tự sinh một chuỗi ngẫu nhiên 24 ký tự vào cột `auth_token`. Thêm hàm `regenerate_auth_token` để đổi token mới (dùng khi đăng xuất).
- `has_many :articles, dependent: :destroy`: một user có nhiều bài; `user.articles` trả về các bài của user. `dependent: :destroy` → **xóa user thì xóa luôn bài của họ** (và bài lại xóa comment của nó, xem `Article`).
- `normalizes :email, with: ->(e) { e.strip.downcase }` (tính năng mới của Rails 7.1): mỗi khi gán email, tự bỏ khoảng trắng 2 đầu và đổi thành chữ thường. Nó cũng áp dụng khi **tìm kiếm** (`find_by(email: "ALICE@x.com")` vẫn tìm ra `alice@x.com`).
  - **(cú pháp)** `->(e) { ... }` là **lambda**: một hàm nhỏ không tên, nhận tham số `e`. `e.strip.downcase` gọi nối tiếp 2 hàm trên chuỗi.
- `validates :email, presence: true, uniqueness: true, format: {...}`:
  - `presence`: không được trống;
  - `uniqueness`: Rails kiểm tra trước khi lưu xem đã có ai dùng email này chưa (database còn có index unique làm lớp bảo vệ thứ hai);
  - `format: { with: URI::MailTo::EMAIL_REGEXP }`: phải đúng dạng email. `URI::MailTo::EMAIL_REGEXP` là biểu thức chính quy có sẵn trong thư viện chuẩn Ruby. **(cú pháp)** `::` nghĩa là "lấy thứ nằm bên trong": hằng `EMAIL_REGEXP` nằm trong `MailTo`, `MailTo` nằm trong `URI`.
- `validates :password, ..., length: { minimum: 6 }, allow_nil: true`: mật khẩu ít nhất 6 ký tự. `allow_nil: true` nghĩa là khi **sửa** user mà không đổi mật khẩu (password là `nil`) thì bỏ qua kiểm tra này. Khi tạo mới, `has_secure_password` đã bắt buộc phải có mật khẩu.

Khi validate lỗi, `user.errors` có dạng `{ email: ["has already been taken"], password: ["is too short (minimum is 6 characters)"] }`. Frontend dùng đúng cấu trúc này để tô đỏ từng ô.

### 3.3 Model `Article` (`app/models/article.rb`)

```ruby
class Article < ApplicationRecord
    # public: everyone, private: logged-in members, archived: only the author and admins
    STATUSES = %w[public private archived]

    belongs_to :user
    has_many :comments, dependent: :destroy

    validates :title, presence: true
    validates :body, presence: true, length: { minimum: 10 }
    validates :status, inclusion: { in: STATUSES }

    def self.visible_to(user)
        return where(status: "public") unless user
        return all if user.admin?
        where(status: ["public", "private"]).or(where(user: user))
    end
end
```

- `STATUSES = %w[public private archived]`: **(cú pháp)** tên viết HOA là **hằng số**. `%w[a b c]` là cách viết tắt của mảng chuỗi `["a", "b", "c"]`. Từ ngoài gọi được bằng `Article::STATUSES`.
- Ý nghĩa 3 trạng thái:

  | status | Ai xem được | Nhãn trên giao diện |
  |---|---|---|
  | `public` | Tất cả, kể cả khách | Công khai |
  | `private` | Mọi người **đã đăng nhập** | Thành viên |
  | `archived` | Chỉ **tác giả** và **admin** | Lưu trữ |

- `belongs_to :user`: mỗi bài thuộc một user; `article.user` trả về tác giả. Rails mặc định **bắt buộc** phải có user, nên không tạo được bài "vô chủ".
- `has_many :comments, dependent: :destroy`: xóa bài thì xóa luôn comment của bài.
- `validates :status, inclusion: { in: STATUSES }`: status phải là 1 trong 3 giá trị. Gửi `"secret"` → lỗi `"is not included in the list"`.
- `def self.visible_to(user)`: **(cú pháp)** `self.` nghĩa là hàm của **lớp** (gọi `Article.visible_to(...)`), không phải của một bài cụ thể. Đây là **trái tim của phân quyền xem bài**:
  - `return where(status: "public") unless user`: **(cú pháp)** `unless` = "nếu không". Không có user (khách) → chỉ bài public. `where(...)` sinh câu SQL `WHERE status = 'public'`.
  - `return all if user.admin?`: admin → tất cả. **(cú pháp)** hàm kết thúc bằng `?` theo quy ước trả về true/false; Rails tự tạo `admin?` từ cột `admin`.
  - `where(status: ["public", "private"]).or(where(user: user))`: thành viên → bài public **hoặc** private, **hoặc** bài do chính mình viết (kể cả archived). SQL tương ứng: `WHERE status IN ('public','private') OR user_id = ?`.
  - Hàm trả về một **relation** (câu truy vấn chưa chạy), nên có thể nối tiếp: `Article.visible_to(u).includes(:user).order(...)`, `Article.visible_to(u).find(id)`.

### 3.4 Model `Comment` (`app/models/comment.rb`)

```ruby
class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :article

  validates :body, presence: true
end
```

- Comment thuộc về một user (người viết) và một bài.
- `validates :body, presence: true`: không cho comment rỗng. `presence` coi chuỗi chỉ có khoảng trắng (`"   "`) cũng là rỗng.
- Comment **không có status riêng**: ai xem được bài thì xem được mọi comment của bài đó.
- Cột `commenter` lưu tên người viết **tại thời điểm comment**. Controller tự điền từ `current_user.name`, người dùng không gửi được.

### 3.5 `Api::BaseController`: xác định "ai đang gọi"

```ruby
class Api::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  private
    def current_user
        @current_user ||= authenticate_with_http_token do |token, options|
            User.find_by(auth_token: token)
        end
    end

    def require_login
        head :unauthorized unless current_user
    end
end
```

- `< ActionController::API`: bản controller **gọn nhẹ cho API** (không có cookie session, không có CSRF, không vẽ HTML). Mọi controller API khác kế thừa từ `Api::BaseController`, nên đều có `current_user` và `require_login`.
- `include ...Token::ControllerMethods`: thêm hàm `authenticate_with_http_token`. **(cú pháp)** `include` = "trộn" các hàm của một module vào class này.
- `private`: các hàm bên dưới **không phải action**, URL không gọi thẳng vào được.
- `current_user`:
  - `authenticate_with_http_token do |token, options| ... end`: đọc header `Authorization: Bearer abc123` (hoặc `Token abc123`), tách ra `token = "abc123"`, rồi chạy khối `do...end`. Không có header → trả `nil`.
  - **(cú pháp)** `do |token, options| ... end` là một **block**: đoạn code truyền vào hàm, `|token, options|` là tham số của block.
  - `User.find_by(auth_token: token)`: tìm user có token đó; không thấy → `nil` (khác `find`, `find_by` không báo lỗi).
  - `@current_user ||= ...`: **(cú pháp)** `@` là **biến của đối tượng** (sống suốt request). `a ||= b` nghĩa là "nếu `a` chưa có giá trị thì gán `b`". Nhờ vậy gọi `current_user` 5 lần trong một request chỉ truy vấn database 1 lần (*memoization*).
- `require_login`: `head :unauthorized` trả về **401 rỗng** (chỉ có mã, không có nội dung) nếu không có user. Dùng làm `before_action`: khi một `before_action` đã trả response, Rails **dừng**, action phía sau không chạy.

### 3.6 `Api::UsersController`: đăng ký

```ruby
class Api::UsersController < Api::BaseController
  def create
    user = User.new(user_params)

    if user.save
      render json: { token: user.auth_token, user: user.slice(:id, :name, :email) }, status: :created
    else
      render json: user.errors, status: :unprocessable_content
    end
  end

  private
    # No :admin here, so nobody can sign themselves up as admin
    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end
end
```

- `User.new(user_params)`: tạo user trong bộ nhớ (chưa lưu).
- `user.save`: chạy toàn bộ validate → đúng thì lưu và trả `true`, sai thì trả `false` và điền `user.errors`.
- Thành công → `201 Created` kèm token (để đăng nhập luôn) và thông tin cơ bản. `user.slice(:id, :name, :email)` chỉ lấy 3 trường → **không lộ** `password_digest`, `auth_token`, `admin`.
- Thất bại → `422` kèm lỗi từng ô.
- `user_params` là **strong parameters**:
  - `params.require(:user)`: request bắt buộc có khóa `user` (thiếu → 400 Bad Request);
  - `.permit(...)`: **chỉ cho qua** các trường liệt kê. Ai đó gửi thêm `admin: true` → bị bỏ đi âm thầm. Đây là chống lỗi **mass assignment** (tự cấp quyền admin). Có test cho trường hợp này.

### 3.7 `Api::SessionsController`: đăng nhập, "tôi là ai", đăng xuất

```ruby
class Api::SessionsController < Api::BaseController
  before_action :require_login, only: [:show, :destroy]

  def create
    user = User.authenticate_by(email: params[:email], password: params[:password])
    if user
      render json: { token: user.auth_token, user: user.slice(:id, :name, :email) }
    else
      head :unauthorized
    end
  end

  def show
    render json: current_user.slice(:id, :name, :email, :admin)
  end

  def destroy
    current_user.regenerate_auth_token
    head :no_content
  end
end
```

- `before_action :require_login, only: [:show, :destroy]`: muốn hỏi "tôi là ai" hay đăng xuất thì phải đăng nhập. `create` (đăng nhập) thì không cần, nên không có trong `only`.
- `create`:
  - `User.authenticate_by(...)` (Rails 7.1): tìm user theo email rồi so mật khẩu với `password_digest`. Đúng → trả user; sai email **hoặc** sai mật khẩu → `nil`. Hàm này **tốn thời gian như nhau** dù email có tồn tại hay không, nên kẻ xấu không đo thời gian phản hồi để dò email nào đã đăng ký được.
  - Sai → 401 rỗng. Frontend hiện chung một câu "Sai email hoặc mật khẩu", cũng để không lộ email nào tồn tại.
- `show`: trả user hiện tại **kèm `admin`**. Frontend gọi API này sau khi đăng nhập và mỗi lần tải trang.
- `destroy` (đăng xuất): `regenerate_auth_token` đổi sang token mới → token cũ (có thể đang nằm trong cookie máy khác) **hết hiệu lực ngay**. Trả `204 No Content`.

### 3.8 `Api::ArticlesController`: bài viết

```ruby
class Api::ArticlesController < Api::BaseController
  before_action :require_login, except: [:index, :show]
  before_action :set_article, only: [:show, :update, :destroy]

  AUTHOR_JSON = { only: [:id, :name] }

  def index
    render json: Article.visible_to(current_user).includes(:user).order(created_at: :desc), include: { user: AUTHOR_JSON }
  end

  def show
    render json: @article, include: { comments: {}, user: AUTHOR_JSON }
  end

  def create
    article = current_user.articles.new(article_params)
    if article.save
      render json: article, status: :created
    else
      render json: article.errors, status: :unprocessable_content
    end
  end

  def update
    return head :forbidden unless @article.user == current_user
    if @article.update(article_params)
      render json: @article
    else
      render json: @article.errors, status: :unprocessable_content
    end
  end

  def destroy
    return head :forbidden unless @article.user == current_user || current_user.admin?
    @article.destroy
    head :no_content
  end

  private
    def set_article
      @article = Article.visible_to(current_user).find(params[:id])
    end

    def article_params
      params.require(:article).permit(:title, :body, :status)
    end
end
```

**Hai `before_action` chạy trước mọi action, theo thứ tự:**
1. `require_login, except: [:index, :show]`: xem danh sách và xem bài thì khách cũng được; tạo, sửa, xóa phải đăng nhập (401).
2. `set_article, only: [:show, :update, :destroy]`: tìm bài **trong phạm vi được xem** (`visible_to`). `find` không thấy → Rails trả **404**.
   - Vì vậy khách mở bài `private` nhận **404** chứ không phải 403: hệ thống **không xác nhận** là bài đó có tồn tại. Thành viên mở bài `archived` của người khác cũng 404.
   - Hệ quả hay: muốn sửa/xóa bài thì trước hết phải **xem được** bài đó.

**`AUTHOR_JSON = { only: [:id, :name] }`**: khi kèm thông tin tác giả vào JSON, **chỉ lấy id và name**. Nếu viết `include: :user` thì JSON sẽ chứa cả `password_digest` và `auth_token` của tác giả → ai cũng lấy được token để đăng nhập thay họ. Có test kiểm tra JSON không chứa 2 thứ này.

**Từng action:**
- `index`:
  - `visible_to(current_user)`: lọc theo người xem;
  - `.includes(:user)`: tải **tất cả tác giả trong 1 câu SQL** thay vì mỗi bài 1 câu (tránh lỗi **N+1 query**: 100 bài sẽ thành 101 câu SQL);
  - `.order(created_at: :desc)`: bài **mới nhất lên đầu**;
  - `include: { user: AUTHOR_JSON }`: mỗi bài trong JSON có thêm `"user": { "id": 1, "name": "Alice" }`.
- `show`: trả bài kèm **toàn bộ comment** và tác giả. `comments: {}` nghĩa là lấy mọi cột của comment (không có cột nhạy cảm).
- `create`:
  - `current_user.articles.new(...)`: tạo bài **gắn sẵn với người đang đăng nhập**. Người dùng có gửi `user_id` cũng vô ích vì `article_params` không permit `user_id` (có test);
  - không gửi status → database dùng mặc định `public`.
- `update`:
  - `return head :forbidden unless @article.user == current_user`: **chỉ tác giả** được sửa → người khác nhận 403. **Admin cũng không được sửa** bài người khác (theo bảng phân quyền: admin chỉ dọn dẹp bằng cách xóa, không sửa nội dung người khác viết).
  - **(cú pháp)** `return X unless Y` = "nếu không phải Y thì trả X và dừng hàm".
  - `@article.update(...)`: gán giá trị mới + validate + lưu; trả true/false như `save`.
- `destroy`: tác giả **hoặc** admin được xóa. `||` = "hoặc". Xóa thành công trả 204.

**403 khác 404 thế nào ở đây?** Bạn *xem được* bài nhưng *không có quyền* sửa → 403. Bạn *không xem được* bài → 404.

### 3.9 `Api::CommentsController`: comment

```ruby
class Api::CommentsController < Api::BaseController
  before_action :require_login

  def create
    article = Article.visible_to(current_user).find(params[:article_id])
    comment = article.comments.new(comment_params.merge(user: current_user, commenter: current_user.name))
    if comment.save
      render json: comment, status: :created
    else
      render json: comment.errors, status: :unprocessable_content
    end
  end

  def destroy
    comment = Article.visible_to(current_user).find(params[:article_id]).comments.find(params[:id])
    return head :forbidden unless comment.user == current_user || current_user.admin?
    comment.destroy
    head :no_content
  end

  private
    def comment_params
      params.require(:comment).permit(:body)
    end
end
```

- `before_action :require_login` (không có `only`/`except`): **mọi** action đều cần đăng nhập.
- `create`:
  - Tìm bài qua `visible_to` → không comment được vào bài mình không xem được (404).
  - `comment_params.merge(user: current_user, commenter: current_user.name)`: **(cú pháp)** `merge` gộp 2 hash. Người viết và tên hiển thị **luôn lấy từ tài khoản đang đăng nhập**, không lấy từ dữ liệu gửi lên → không ai mạo danh người khác được (có test: gửi `commenter: "Someone else"` vẫn lưu tên Bob).
  - `permit(:body)`: chỉ nhận nội dung.
- `destroy`:
  - `...find(params[:article_id]).comments.find(params[:id])`: tìm comment **trong đúng bài trên URL**. Gửi id comment của bài A vào URL của bài B → 404 (có test).
  - Chỉ **người viết comment** hoặc **admin** được xóa. **Tác giả bài không được xóa comment của người khác** (để tác giả không xóa được góp ý trái chiều).

### 3.10 Bảng mã HTTP dùng trong API

| Mã | Tên trong Rails | Khi nào |
|---|---|---|
| 200 | `:ok` | Đọc hoặc sửa thành công |
| 201 | `:created` | Tạo mới thành công (đăng ký, bài, comment) |
| 204 | `:no_content` | Xóa hoặc đăng xuất thành công (không có nội dung trả về) |
| 400 | (tự động) | Thiếu khóa bắt buộc, ví dụ không có `article` trong body |
| 401 | `:unauthorized` | Chưa đăng nhập, token sai, hoặc sai email/mật khẩu |
| 403 | `:forbidden` | Đã đăng nhập, xem được, nhưng không có quyền làm việc này |
| 404 | (tự động khi `find` không thấy) | Không tồn tại **hoặc** không được phép xem |
| 422 | `:unprocessable_content` | Dữ liệu sai validate; body là lỗi từng ô |

`:unprocessable_content` là tên mới của `:unprocessable_entity` (Rack 3 đổi tên, mã vẫn là 422). Dùng tên cũ thì vẫn chạy nhưng in cảnh báo.

### 3.11 Các file cấu hình đã chạm tới

**`config/puma.rb`** (Puma là web server chạy Rails):
```ruby
# Windows: first mtime read is whole seconds, later ones are not, so this plugin restarts at boot and crashes
plugin :tmp_restart unless Gem.win_platform?
```
Plugin `tmp_restart` cứ 2 giây xem giờ sửa của file `tmp/restart.txt`; nếu file mới hơn thì restart server. Trên Windows, lần đọc đầu bị làm tròn tới giây (`21:46:38.000`), các lần sau có phần lẻ (`21:46:38.089`) → Puma tưởng file vừa bị sửa → restart → trên Windows không restart được → **sập**. Nên tắt plugin này khi chạy trên Windows (`Gem.win_platform?` trả true trên Windows). Mac/Linux không đổi.

**`Gemfile`**:
```ruby
group :test do
  gem "minitest", "< 6"
  ...
end
```
`Gemfile.lock` gốc khóa `minitest 6.1.0`, bản này không tương thích với Rails 7.1 → `bin/rails test` báo `ArgumentError` ngay khi chạy, trên mọi máy. Giới hạn `< 6` thì Bundler chọn `5.27.0`.

**`Gemfile.lock`**: có thêm platform `x64-mingw-ucrt` (Windows) để máy Windows dùng được bản build sẵn của `sqlite3`, `nokogiri`.

---

## 4. Frontend Nuxt

### 4.1 Cấu trúc thư mục: Nuxt tự hiểu theo tên thư mục

| Thư mục | Nuxt làm gì |
|---|---|
| `pages/` | Mỗi file là **một trang**, đường dẫn theo tên file: `pages/login.vue` → `/login`, `pages/articles/[id]/edit.vue` → `/articles/5/edit` (`[id]` là phần thay đổi) |
| `layouts/default.vue` | Khung chung (header, footer) bọc mọi trang |
| `components/` | Mảnh giao diện dùng lại; tự import, dùng thẳng `<ArticleForm>` |
| `composables/` | Hàm `useXxx()` dùng chung logic; tự import |
| `utils/` | Hàm tiện ích; tự import |
| `middleware/` | Hàm chạy **trước khi vào trang** |
| `plugins/` | Chạy **một lần khi app khởi động** (`.server.ts` = chỉ trên server) |

"Tự import" nghĩa là không cần viết `import { useAuth } from '...'`, Nuxt tự tìm.

### 4.2 `nuxt.config.ts`

```ts
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  devServer: { port: 8000 },
  modules: ['@ant-design-vue/nuxt'],
  antd: { extractStyle: true },
  routeRules: {
    '/api/**': { proxy: 'http://localhost:3000/api/**' }
  },
  css: ['ant-design-vue/dist/reset.css', '~/assets/css/main.css'],
})
```

- `devServer: { port: 8000 }`: Rails đã chiếm 3000.
- `modules: ['@ant-design-vue/nuxt']`: dùng được mọi component `<a-button>`, `<a-form>`... và icon `<UserOutlined />` mà không cần import.
- `antd: { extractStyle: true }` (đi cùng `<AExtractStyle>` trong `app.vue`): đưa CSS của Ant Design vào HTML do server dựng → trang có màu sắc ngay, không bị "nháy" trắng trơn rồi mới có style.
- `routeRules` với `proxy`: request tới `http://localhost:8000/api/articles` được Nuxt gửi tiếp sang `http://localhost:3000/api/articles` rồi trả kết quả về. **(cú pháp)** `**` nghĩa là "mọi thứ phía sau".
- `css`: nạp CSS reset của Ant Design (xóa margin mặc định của trình duyệt) rồi tới CSS riêng `main.css`.

### 4.3 `app.vue`

```vue
<NuxtRouteAnnouncer />
<AExtractStyle>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</AExtractStyle>
```
- `<NuxtRouteAnnouncer />`: đọc tên trang mới cho người dùng trình đọc màn hình khi chuyển trang (trợ năng).
- `<NuxtLayout>` bọc trang trong `layouts/default.vue`; `<NuxtPage />` là chỗ trang hiện tại hiển thị.

### 4.4 `composables/useAuth.ts`: trung tâm đăng nhập phía frontend

```ts
type User = { id: number; name: string; email: string; admin: boolean }

export function useAuth() {
    const token = useCookie<string | null>('token', { maxAge: 60 * 60 * 24 * 30, sameSite: 'lax' })
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
        await fetchUser()
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
```

- `type User = {...}`: **(cú pháp TypeScript)** mô tả hình dạng dữ liệu user để trình soạn thảo gợi ý và báo lỗi gõ sai tên trường. Không ảnh hưởng lúc chạy.
- `useCookie('token', {...})`: một **ref** gắn với cookie tên `token`. Đọc `token.value` là đọc cookie; gán `token.value = 'abc'` là ghi cookie; gán `null` là xóa cookie. Chạy được **cả trên server Nuxt** (đọc cookie từ request) lẫn trình duyệt.
  - `maxAge: 60 * 60 * 24 * 30`: cookie sống 30 ngày (tính bằng giây).
  - `sameSite: 'lax'`: trình duyệt không gửi cookie này khi trang **web khác** gửi request ngầm tới blog (giảm nguy cơ tấn công CSRF).
  - **(cú pháp)** `useCookie<string | null>`: `<...>` là kiểu dữ liệu, `string | null` = "chuỗi hoặc null".
- `useState('user', () => null)`: **trạng thái dùng chung** cho mọi component, có khóa `'user'`. Đặc biệt: giá trị đặt trên server Nuxt được **gửi kèm xuống trình duyệt** trong HTML, nên trình duyệt không phải gọi lại API. `() => null` là giá trị ban đầu.
- `computed(() => ...)`: giá trị **tự tính lại** mỗi khi `token` đổi.
  - **(cú pháp)** `điều_kiện ? A : B` là toán tử ba ngôi: đúng thì A, sai thì B. Có token → `{ Authorization: 'Bearer abc' }`, không có → `{}`.
  - **(cú pháp)** `` `Bearer ${token.value}` `` là **template string**: chèn giá trị vào chuỗi.
- `fetchUser()`:
  - `if (!token.value) return (user.value = null)`: **(cú pháp)** `!` = phủ định. Không có token thì chắc chắn là khách.
  - `await $fetch(...)`: gọi `GET /api/session`. `$fetch` **ném lỗi** nếu mã trả về là 4xx/5xx, nên phải bọc `try/catch`.
  - `catch (e)`: nếu Rails trả **401** (token sai hoặc đã đăng xuất ở máy khác) → **xóa cookie hỏng**. Lỗi khác (ví dụ Rails đang tắt) → **giữ** cookie, chỉ coi như khách lúc này; khi Rails bật lại người dùng vẫn đăng nhập.
- `login()`: gọi `POST /api/session` → nhận token → lưu cookie → gọi `fetchUser()` để biết thêm `admin` (API đăng nhập không trả `admin`).
- `register()`: tương tự, gọi `POST /api/registration` với body `{ user: form }` (Rails `params.require(:user)` cần khóa `user`).
- `logout()`:
  - gọi `DELETE /api/session` để Rails đổi token. `.catch(() => { })`: lỗi mạng cũng bỏ qua, vì dù sao vẫn phải xóa token ở máy này;
  - xóa cookie và user, về trang chủ.
- `return {...}`: trả ra để component dùng: `const { user, logout } = useAuth()`. **(cú pháp)** `const { a, b } = obj` là **destructuring**: lấy các trường `a`, `b` của `obj` ra thành biến.

**Vì sao `headers` có 2 cách dùng?** (ghi trong CLAUDE.md)
- `useFetch(url, { headers })`: truyền **ref** `headers` → `useFetch` tự đọc giá trị mới nhất.
- `$fetch(url, { headers: headers.value })`: `$fetch` chỉ nhận **giá trị thật**, nên phải `.value`.

### 4.5 `plugins/auth.server.ts`

```ts
export default defineNuxtPlugin(async () => {
  await useAuth().fetchUser()
})
```
- Đuôi `.server.ts` → chỉ chạy **trên server Nuxt**, mỗi lần một trang được tải (F5 hoặc mở link mới).
- Plugin chạy **trước** middleware và trang → khi middleware kiểm tra `user`, thông tin đã có sẵn.
- Nhờ `useState`, user đi xuống trình duyệt cùng HTML. Khi bấm link chuyển trang trong trình duyệt, plugin không chạy lại; `user` vẫn còn trong `useState`.

### 4.6 `middleware/auth.ts` và `middleware/guest.ts`

```ts
// auth.ts
export default defineNuxtRouteMiddleware((to) => {
  const { user } = useAuth()
  if (!user.value) {
    return navigateTo({ path: '/login', query: { redirect: to.fullPath } })
  }
})
```
- Tên file = tên middleware. Trang muốn dùng thì khai báo `definePageMeta({ middleware: 'auth' })`.
- `to`: route sắp vào. `to.fullPath` ví dụ `/articles/5/edit`.
- Kiểm tra `user` chứ không kiểm tra `token`: token có thể còn trong cookie nhưng đã hết hiệu lực; `user` chỉ có khi Rails xác nhận token đúng.
- `return navigateTo(...)`: chuyển hướng. **Phải có `return`**, không thì Nuxt vẫn cho vào trang. Trên server, lệnh này thành mã **302** (đã thử bằng curl).
- `query: { redirect: to.fullPath }`: thêm `?redirect=/articles/5/edit` để đăng nhập xong quay lại đúng chỗ.

```ts
// guest.ts
export default defineNuxtRouteMiddleware(() => {
  if (useAuth().user.value) return navigateTo('/')
})
```
- Ngược lại: đã đăng nhập mà vào `/login` hay `/register` → về trang chủ.

| Trang | Middleware |
|---|---|
| `/articles/new` | `auth` |
| `/articles/:id/edit` | `auth` (+ kiểm tra tác giả trong trang) |
| `/login`, `/register` | `guest` |
| `/`, `/articles/:id` | không có (khách xem được bài public) |

### 4.7 `layouts/default.vue`: header và footer

Phần script:
```ts
const { user, logout } = useAuth()
```

Phần template, các ý chính:
- `<template v-if="user">...</template><template v-else>...</template>`: **(cú pháp Vue)** `v-if`/`v-else` hiện khối này hoặc khối kia. Đã đăng nhập: nút "New Article" + menu người dùng. Khách: "Đăng nhập" + "Đăng ký".
- Mẫu `NuxtLink` + `a-button`:
  ```vue
  <NuxtLink v-slot="{ href, navigate }" to="/articles/new" custom>
    <a-button type="primary" :href="href" @click="navigate">...</a-button>
  </NuxtLink>
  ```
  `custom` nghĩa là NuxtLink **không tự vẽ thẻ `<a>`** mà đưa ra `href` (địa chỉ) và `navigate` (hàm chuyển trang không tải lại). `a-button` có `href` sẽ tự vẽ thành thẻ `<a>`. Kết quả là **một thẻ `<a>` duy nhất** có giao diện nút, thay vì nút nằm trong link (sai chuẩn HTML). **(cú pháp Vue)** `:href` (có dấu `:`) = gán giá trị JS; `@click` = gắn sự kiện.
- `aria-label="New Article"`: trên điện thoại chữ bị ẩn, trình đọc màn hình vẫn đọc được tên nút.
- Menu người dùng: `<a-dropdown :trigger="['click']">` bấm mới mở. Bên trong: avatar là chữ cái đầu tên (`user.name[0]?.toUpperCase()`), email (mục bị vô hiệu, chỉ để xem), "Đăng xuất" gọi `logout`.
  - **(cú pháp)** `?.` là **optional chaining**: nếu `user.name[0]` là `undefined` (tên rỗng) thì trả `undefined` thay vì báo lỗi khi gọi `toUpperCase()`.
- `<slot />`: chỗ nội dung của trang được đặt vào.
- Footer: `new Date().getFullYear()` in năm hiện tại.

CSS đáng nhớ:
- `.site { min-height: 100vh; display: flex; flex-direction: column }` + `.site-content { flex: 1 }`: nội dung giãn ra để **footer luôn nằm đáy** dù trang ngắn.
- `.site-header { position: sticky; top: 0 }`: header **dính trên cùng** khi cuộn; `backdrop-filter: blur(8px)` làm mờ nội dung chạy bên dưới.
- `@media (max-width: 576px) { .hide-mobile { display: none } }`: màn hình nhỏ hơn 576px thì ẩn chữ, chỉ còn icon.
- `<style scoped>`: CSS chỉ áp dụng cho component này, không ảnh hưởng chỗ khác.

### 4.8 `pages/index.vue`: trang chủ (danh sách bài)

```ts
type Article = { id: number; title: string; body: string; status: string; created_at: string; updated_at: string; user: { id: number; name: string } | null }
const { headers } = useAuth()
const { data: articles, error } = await useFetch<Article[]>('/api/articles', { headers })
```
- `useFetch`: hàm lấy dữ liệu **thân thiện với SSR**. Lúc F5, server Nuxt gọi API rồi gửi kết quả kèm HTML; trình duyệt **không gọi lại**. Trả về `data` (dữ liệu), `error` (lỗi nếu có), `refresh` (gọi lại).
  - **(cú pháp)** `const { data: articles } = ...`: lấy trường `data` và **đổi tên** thành `articles`.
  - Gửi `headers` → Rails biết ai xem → trả đúng danh sách theo quyền.
- Template:
  - `<a-alert v-if="error">`: lỗi (ví dụ Rails tắt) thì báo lỗi, không vẽ danh sách.
  - `<a-list :data-source="articles ?? []">`: **(cú pháp)** `??` là **nullish coalescing**: nếu `articles` là `null`/`undefined` thì dùng `[]`.
  - `<template #renderItem="{ item }">`: Ant Design gọi phần này cho **từng bài**, `item` là bài đó. **(cú pháp Vue)** `#tên` là slot có tên.
  - Tiêu đề là link tới `/articles/${item.id}`.
  - **Mới:** `<a-tag v-if="item.status !== 'public'" ...>{{ statusLabel[item.status] }}</a-tag>`: bài không công khai có nhãn "Thành viên" (cam) hoặc "Lưu trữ" (xám), để tác giả/admin biết bài nào người khác không thấy. **(cú pháp)** `!==` là "khác" so sánh chặt.
  - Dưới mỗi bài: tác giả (`item.user?.name ?? 'Không rõ'`, phòng bài cũ không có tác giả) và ngày tạo `formatDate(...)`.
- CSS:
  - `.body-preview` với `-webkit-line-clamp: 2`: nội dung dài chỉ hiện **tối đa 2 dòng**, phần sau thành "...".
  - `.title-link { line-height: 32px }`: tiêu đề cao bằng avatar 32px nên nằm giữa avatar. Đặt CSS trên **class của mình** vì rule của Ant Design trên `.ant-list-item-meta-title` cụ thể hơn (specificity cao hơn) sẽ thắng.

### 4.9 `pages/login.vue`: đăng nhập

```ts
definePageMeta({ middleware: 'guest' })
const { login } = useAuth()
const form = reactive({ email: '', password: '' })
const error = ref('')
const loading = ref(false)

async function submit() {
  loading.value = true
  error.value = ''
  try {
    await login(form.email, form.password)
    const redirect = useRoute().query.redirect
    await navigateTo(typeof redirect === 'string' && redirect.startsWith('/') ? redirect : '/')
  } catch (e: any) {
    if (e.status !== 401) throw e
    error.value = 'Sai email hoặc mật khẩu'
  } finally {
    loading.value = false
  }
}
```
- `definePageMeta({ middleware: 'guest' })`: đã đăng nhập thì không vào được trang này.
- `reactive({...})` và `ref('')`: **(Vue)** dữ liệu "phản ứng": đổi giá trị thì giao diện tự vẽ lại.
  - `reactive` dùng cho **object**, truy cập thẳng `form.email`.
  - `ref` dùng cho **giá trị đơn**, truy cập qua `.value` trong script (trong template thì không cần `.value`).
- `submit()`:
  - `loading.value = true` → nút hiện vòng quay, tránh bấm 2 lần.
  - Sau khi đăng nhập: đọc `?redirect=` trên URL. Chỉ chấp nhận nếu là **chuỗi** và **bắt đầu bằng `/`** (đường dẫn nội bộ). Không hợp lệ → về `/`. Đây là chống **open redirect** (link lừa `?redirect=https://trang-gia.com`). `navigateTo` của Nuxt cũng tự từ chối link ra ngoài (`//trang-gia.com`), nên có 2 lớp.
  - `catch`: chỉ xử lý **401** (sai email/mật khẩu); lỗi khác `throw e` ném tiếp để Nuxt hiện trang lỗi, tránh nuốt mất lỗi thật.
  - `finally`: **luôn chạy** dù thành công hay lỗi → tắt vòng quay.
- Template:
  - `<AuthCard>` là khung chung (mục 4.15).
  - `<a-form :model="form" @finish="submit">`: `@finish` chỉ chạy khi **mọi rule đã qua**.
  - `:rules="[{ required: true, type: 'email', message: '...' }]"`: kiểm tra ngay trên trình duyệt (bắt buộc, đúng dạng email).
  - `<a-input v-model:value="form.email">`: **(Vue)** `v-model` = liên kết 2 chiều: gõ vào ô thì `form.email` đổi và ngược lại. Ant Design dùng prop tên `value`, nên viết `v-model:value`.
  - `autocomplete="email"` / `"current-password"`: trình duyệt và trình quản lý mật khẩu điền đúng ô.

### 4.10 `pages/register.vue`: đăng ký

```ts
definePageMeta({ middleware: 'guest' })
const { register } = useAuth()
const form = reactive({ name: '', email: '', password: '', password_confirmation: '' })
const errors = ref<Record<string, string[]>>({})
const loading = ref(false)

const confirmRules = [
  { required: true, message: 'Nhập lại mật khẩu' },
  {
    validator: (_rule: any, value: string) =>
      value === form.password ? Promise.resolve() : Promise.reject('Mật khẩu nhập lại không khớp')
  }
]

async function submit() {
  loading.value = true
  errors.value = {}
  try {
    await register(form)
    await navigateTo('/')
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data
  } finally {
    loading.value = false
  }
}
```
- `Record<string, string[]>`: **(TS)** object có khóa là chuỗi, giá trị là mảng chuỗi, đúng dạng lỗi Rails trả về `{ email: ["has already been taken"] }`.
- `confirmRules`: rule tự viết. Ant Design gọi `validator`; trả `Promise.resolve()` là hợp lệ, `Promise.reject('...')` là lỗi kèm thông báo. `_rule` có dấu gạch dưới là quy ước "tham số không dùng tới".
- Kiểm tra **hai lớp**:
  1. **Trình duyệt** (rules của `a-form-item`): trống, sai dạng email, dưới 6 ký tự, nhập lại không khớp → báo ngay, chưa gửi request.
  2. **Rails** (validate trong model): email đã có người dùng, email sai định dạng (khi ai đó gọi thẳng API)... → trả 422 → `errors.value = e.data`.
- `v-bind="fieldState(errors, 'email', 'Email')"`: biến lỗi của Rails thành props cho ô (mục 4.16). **(Vue)** `v-bind="object"` = rải mọi trường của object thành props.
- Đã thử: nhập `ZZ-BOB@x.com` (viết hoa) trùng email có sẵn → ô Email đỏ, "Email has already been taken", vì Rails chuẩn hóa về chữ thường trước khi kiểm tra.

### 4.11 `pages/articles/new.vue`: tạo bài

```ts
definePageMeta({ middleware: 'auth' })
const errors = ref<Record<string, string[]>>({})
const { headers } = useAuth()
async function create(article: object) {
  try {
    const created = await $fetch<{ id: number }>('/api/articles', {
      method: 'POST',
      body: { article },
      headers: headers.value
    })
    await navigateTo(`/articles/${created.id}`)
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data
  }
}
```
- Khách bị middleware `auth` chuyển sang `/login?redirect=/articles/new`.
- `create(article)` được gọi khi `ArticleForm` phát sự kiện `submit`.
- `body: { article }`: **(cú pháp)** viết tắt của `{ article: article }`. Rails cần khóa `article` (`params.require(:article)`).
- Thành công → sang trang bài vừa tạo. Lỗi 422 → đưa lỗi xuống form.

### 4.12 `pages/articles/[id]/edit.vue`: sửa bài

```ts
definePageMeta({ middleware: 'auth' })
const id = useRoute().params.id
const { headers, user } = useAuth()
const { data: article, error } = await useFetch<any>(`/api/articles/${id}`, { headers })
const errors = ref<Record<string, string[]>>({})

if (error.value){
  throw createError({ statusCode: error.value.statusCode ?? 500, statusMessage: 'Bài viết này không tồn tại.', fatal: true })
}

if (article.value.user_id !== user.value?.id) {
  throw createError({ statusCode: 403, statusMessage: 'Bạn không phải tác giả bài này.', fatal: true })
}

async function update(changes: object) {
  try {
    await $fetch(`/api/articles/${id}`, { method: 'PATCH', body: { article: changes }, headers: headers.value })
    await navigateTo(`/articles/${id}`)
  } catch (e: any) {
    if (e.status !== 422) throw e
    errors.value = e.data
  }
}
```
- `useRoute().params.id`: lấy `5` từ URL `/articles/5/edit` (tên `id` đến từ tên thư mục `[id]`).
- Tải bài trước để điền sẵn vào form.
- `throw createError({... fatal: true})`: dừng trang, hiện **trang lỗi** của Nuxt với mã tương ứng. Không xem được bài → Rails trả 404 → trang lỗi 404.
- Kiểm tra tác giả: không phải tác giả → **403** ngay, không hiện form. Admin cũng nhận 403 (khớp luật Rails). Đã thử: Bob sửa bài Alice → 403, admin → 403, Alice → 200.
- `PATCH`: chỉ gửi các trường thay đổi (ở đây gửi cả form).

### 4.13 `pages/articles/[id]/index.vue`: xem bài và comment

Script:
```ts
type Comment = { id: number; commenter: string; body: string; user_id: number | null }
const { headers, user } = useAuth()
const id = useRoute().params.id
const { data: article, refresh, error } = await useFetch<any>(`/api/articles/${id}`, { headers })
if (error.value) { throw createError({ ... }) }

const comments = computed<Comment[]>(() => article.value?.comments ?? [])

const isAuthor = computed(() => !!user.value && user.value.id === article.value?.user_id)
const canDestroyArticle = computed(() => isAuthor.value || !!user.value?.admin)
const canDestroyComment = (c: Comment) => !!user.value && (c.user_id === user.value.id || user.value.admin)
```
- `comments`: danh sách comment lấy từ bài. (Trước đây có lọc `status !== 'archived'`; giờ comment không còn status.)
- **Ba hàm quyền là bản sao luật Rails, chỉ để ẩn/hiện nút:**
  - `isAuthor`: đã đăng nhập **và** là tác giả → hiện nút **Edit**.
  - `canDestroyArticle`: tác giả **hoặc** admin → hiện nút **Destroy** bài.
  - `canDestroyComment(c)`: người viết comment **hoặc** admin → hiện nút xóa comment đó.
  - **(cú pháp)** `!!x` = ép về true/false. `!!null` → `false`, `!!{...}` → `true`. Dùng để kết quả luôn là boolean thật.
  - `computed` cho giá trị phụ thuộc dữ liệu; `canDestroyComment` là hàm thường vì cần tham số `c`.

```ts
async function destroyArticle() {
  await $fetch(`/api/articles/${id}`, { method: 'DELETE', headers: headers.value })
  await navigateTo('/')
}

const newComment = reactive({ body: '' })
const commentErrors = ref<Record<string, string[]>>({})

async function addComment() {
  try {
    await $fetch(`/api/articles/${id}/comments`, { method: 'POST', body: { comment: newComment }, headers: headers.value })
    newComment.body = ''
    commentErrors.value = {}
    await refresh()
  } catch (e: any) {
    if (e.status !== 422) throw e
    commentErrors.value = e.data
  }
}

async function destroyComment(commentId: number) {
  await $fetch(`/api/articles/${id}/comments/${commentId}`, { method: 'DELETE', headers: headers.value })
  await refresh()
}
```
- `destroyArticle`: chỉ chạy sau khi người dùng bấm "Xóa" trong hộp xác nhận `a-popconfirm`.
- `addComment`: gửi comment → xóa trắng ô nhập → `refresh()` tải lại bài để comment mới hiện ra.
- Không có ô "tên người comment" vì Rails tự lấy tên từ tài khoản.

Template, các phần chính:
- Thẻ trạng thái: `<a-tag :color="statusColor[article.status]">{{ statusLabel[article.status] }}</a-tag>` → "Công khai" xanh, "Thành viên" cam, "Lưu trữ" xám.
- "Sửa lần cuối" chỉ hiện khi `updated_at !== created_at` (Rails đặt hai giá trị bằng nhau lúc tạo, sửa thì `updated_at` đổi).
- `.article-body { white-space: pre-line }`: giữ nguyên xuống dòng tác giả gõ.
- Nút Edit/Destroy nằm trong `v-if="isAuthor || canDestroyArticle"`.
- `<a-popconfirm @confirm="destroyArticle">`: hộp "Xóa bài viết này?" trước khi xóa thật.
- Danh sách comment: `<template v-if="canDestroyComment(item)" #actions>`: đặt `v-if` lên slot → người không có quyền **không có nút** trong HTML.
- Form comment (chỉ khi đăng nhập):
  ```vue
  <a-form-item label="Body" name="body"
    :rules="[{ required: true, whitespace: true, message: 'Nhập nội dung comment' }]"
    v-bind="fieldState(commentErrors, 'body', 'Body')">
  ```
  - `name="body"`: cho `a-form` biết ô này ứng với `newComment.body` để chạy rule.
  - `whitespace: true`: chuỗi chỉ toàn khoảng trắng cũng coi là trống.
  - Đã thử: bấm "Create Comment" khi trống → hiện "Nhập nội dung comment", không gửi request; gõ nội dung rồi gửi → comment hiện ra, ô trống lại, không hiện lỗi.
- Khách: thay form bằng thẻ "Đăng nhập để tham gia bình luận" với 2 nút.

### 4.14 `components/ArticleForm.vue`: form dùng chung cho tạo và sửa

```ts
type Article = { title: string; body: string; status: string | null }

const props = defineProps<{
  article?: Article
  errors?: Record<string, string[]>
  submitLabel?: string
}>()
const emit = defineEmits<{ submit: [Article] }>()

const form = reactive<Article>({
  title: props.article?.title ?? '',
  body: props.article?.body ?? '',
  status: props.article?.status ?? 'public'
})
```
- `defineProps`: khai báo dữ liệu **cha truyền vào**. `article?` có dấu `?` = không bắt buộc (trang tạo mới không truyền).
- `defineEmits<{ submit: [Article] }>()`: component này **phát** sự kiện `submit` kèm 1 bài. Cha nghe bằng `@submit="create"`.
- `form = reactive({...})`: **bản sao** dữ liệu để gõ trong form không làm đổi dữ liệu của cha trước khi lưu. Trang tạo mới: rỗng, status mặc định `public`; trang sửa: điền sẵn.

Template:
```vue
<a-form layout="vertical" :model="form" @finish="emit('submit', { ...form })">
  <a-form-item label="Title" v-bind="fieldState(errors, 'title', 'Title')">...
  <a-form-item label="Body" v-bind="fieldState(errors, 'body', 'Body')">...
  <a-form-item label="Ai được xem" v-bind="fieldState(errors, 'status', 'Status')">
    <a-select id="article-status" v-model:value="form.status" :options="statusOptions" />
  </a-form-item>
```
- `{ ...form }`: **(cú pháp)** **spread**: tạo object mới chép mọi trường của `form`.
- `id="article-status"` cố định: nếu không, `a-select` tự sinh id ngẫu nhiên khác nhau giữa server và trình duyệt → cảnh báo hydration.
- **Mới:** ô "Ai được xem" dùng `statusOptions` tiếng Việt có mô tả (mục 4.16).

### 4.15 `components/AuthCard.vue`: khung trang đăng nhập/đăng ký

```ts
defineProps<{ title: string; subtitle: string }>()
```
Template có **3 slot**:
- `<slot name="icon" />`: icon trong vòng tròn xanh nhạt;
- `<slot />` (mặc định): form;
- `<slot name="footer" />`: dòng "Chưa có tài khoản? Đăng ký".

Trang dùng: `<AuthCard title="..." subtitle="..."><template #icon>...</template> ...form... <template #footer>...</template></AuthCard>`. Hai trang chung một khung → sửa giao diện một chỗ là đủ.

### 4.16 `utils/`

**`fieldState.ts`**: đổi lỗi Rails thành props của ô form
```ts
export function fieldState(errors: Record<string, string[]> | undefined, field: string, label: string) {
  const msgs = errors?.[field]
  return msgs?.length
    ? { validateStatus: 'error' as const, help: msgs.map(m => `${label} ${m}`).join(', ') }
    : {}
}
```
- `errors?.[field]`: lấy lỗi của ô `field` (ví dụ `'email'`); `?.` phòng `errors` là `undefined`.
- Có lỗi → `{ validateStatus: 'error', help: 'Email has already been taken' }`: ô đỏ, dòng chữ đỏ bên dưới. `msgs.map(m => ...)` biến từng thông báo thành "Tên ô + thông báo"; `.join(', ')` nối lại.
- Không lỗi → `{}` (object rỗng) để **không đè** lên rule của trình duyệt. Nếu trả `{ validateStatus: '' }` thì rule `required` không tô đỏ được nữa.
- `'error' as const`: **(TS)** báo kiểu là đúng chữ `'error'` chứ không phải chuỗi bất kỳ, vì `a-form-item` chỉ nhận vài giá trị cố định.

**`formatDate.ts`**: in ngày giờ kiểu Việt Nam
```ts
const timeZone = 'Asia/Ho_Chi_Minh'
export const formatDate = (iso: string) => new Date(iso).toLocaleDateString('vi-VN', { timeZone })
export const formatDateTime = (iso: string) =>
  new Date(iso).toLocaleString('vi-VN', { timeZone, hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit', year: 'numeric' })
```
- Rails lưu giờ theo **UTC** và gửi dạng `2026-11-22T15:59:41.806Z` (`Z` = UTC).
- `toLocaleDateString('vi-VN', ...)` đổi sang `22/11/2026`.
- **Mới:** `timeZone` cố định giờ Việt Nam. Không có nó, server Nuxt deploy ở nước ngoài sẽ in giờ theo múi giờ server, trình duyệt in theo múi giờ máy → 2 giờ khác nhau → lỗi hydration và người dùng thấy sai giờ.
- **(cú pháp)** `{ timeZone }` là viết tắt của `{ timeZone: timeZone }`.

**`articleStatus.ts`** (mới): nhãn, màu và lựa chọn cho status bài
```ts
export const statusLabel: Record<string, string> = { public: 'Công khai', private: 'Thành viên', archived: 'Lưu trữ' }
export const statusColor: Record<string, string> = { public: 'green', private: 'orange', archived: 'default' }
export const statusOptions = [
  { value: 'public', label: 'Công khai: ai cũng xem được' },
  { value: 'private', label: 'Thành viên: phải đăng nhập mới xem được' },
  { value: 'archived', label: 'Lưu trữ: chỉ mình tôi và admin xem được' }
]
```
- `value` là giá trị gửi lên Rails (giữ tiếng Anh, khớp `Article::STATUSES`); `label` là chữ người dùng thấy.
- Gom vào một file để trang chủ, trang bài viết và form cùng dùng, sửa một chỗ là đủ.
- Đổi nhãn "private" thành **"Thành viên"** vì "riêng tư" dễ hiểu nhầm là chỉ mình tôi xem, trong khi thực tế mọi thành viên đăng nhập đều xem được.

### 4.17 `assets/css/main.css`: CSS toàn trang

- `body { background: #f5f5f5 }`: nền xám nhạt để thẻ trắng nổi lên.
- `main { max-width: 800px; margin: 0 auto; padding: 24px 16px }`: nội dung rộng tối đa 800px, căn giữa, chừa lề 16px trên điện thoại.
- `.back-link`, `.page-title`: link "← quay lại" và tiêu đề trang dùng chung.

---

## 5. Các luồng hoàn chỉnh từ đầu đến cuối

### 5.1 Đăng ký
1. Người dùng điền form `/register` → rules trình duyệt kiểm tra.
2. `register(form)` → `POST /api/registration` (qua proxy) → `UsersController#create`.
3. Rails: `permit` lọc trường → `normalizes` email → validate → `has_secure_password` băm mật khẩu → `has_secure_token` sinh token → lưu.
4. Trả `201 { token, user }` → Nuxt ghi cookie `token` → `fetchUser()` → `GET /api/session` → biết `admin`.
5. `navigateTo('/')` → header hiện tên người dùng.

### 5.2 F5 một trang khi đã đăng nhập (SSR)
1. Trình duyệt gửi `GET /articles/5` kèm cookie `token`.
2. Server Nuxt: plugin `auth.server.ts` → `fetchUser()` đọc cookie → hỏi Rails "token này là ai?" → `user` có giá trị.
3. Middleware (nếu trang có) kiểm tra `user`.
4. Trang gọi `useFetch('/api/articles/5', { headers })` → Rails `set_article` lọc theo `visible_to`.
5. Nuxt dựng HTML (có cả nút Edit nếu là tác giả) + nhúng `user` và dữ liệu bài vào trang → gửi trình duyệt.
6. Trình duyệt hiện ngay, rồi hydration để các nút bấm được.

### 5.3 Khách bấm "New Article" qua link có sẵn
1. Middleware `auth` thấy `user` rỗng → `/login?redirect=/articles/new`.
2. Đăng nhập xong → đọc `redirect` → quay lại `/articles/new`.

### 5.4 Thành viên cố sửa bài người khác bằng cách gõ URL
1. Gõ `/articles/1/edit` → middleware `auth` cho qua (đã đăng nhập).
2. Trang tải bài → `user_id` khác `user.id` → trang lỗi **403**.
3. Kể cả khi họ dùng curl gửi thẳng `PATCH /api/articles/1` → Rails `update` trả **403**. Đây mới là lớp chặn thật.

### 5.5 Đăng xuất
1. Menu → "Đăng xuất" → `DELETE /api/session` → Rails `regenerate_auth_token`.
2. Xóa cookie + `user` → về trang chủ, header hiện "Đăng nhập / Đăng ký".
3. Ai đó chép được token cũ → gọi API → 401 (có test).

---

## 6. Bảo mật: những gì đã được bảo vệ

| Nguy cơ | Cách chặn | Ở đâu |
|---|---|---|
| Lộ mật khẩu nếu mất database | Chỉ lưu bản băm bcrypt | `has_secure_password` |
| Dò email nào đã đăng ký | Thời gian xử lý như nhau + cùng một thông báo lỗi | `authenticate_by`, `login.vue` |
| Tự cấp quyền admin khi đăng ký | `permit` không có `:admin` | `UsersController#user_params` |
| Tạo bài/comment dưới tên người khác | Gắn `current_user` ở server, không permit `user_id`/`commenter` | `current_user.articles.new`, `merge(user: ...)` |
| Lộ token/mật khẩu băm qua JSON | `AUTHOR_JSON = { only: [:id, :name] }`, `slice(...)` | ArticlesController, Users/SessionsController |
| Xem bài không được phép | `visible_to` + `find` → 404 | `set_article`, CommentsController |
| Sửa/xóa không phải của mình | So sánh `@article.user == current_user` → 403 | `update`, `destroy` |
| Token bị lộ sau khi đăng xuất | Đổi token khi đăng xuất | `regenerate_auth_token` |
| Đường vòng không kiểm tra quyền | Đã xóa giao diện HTML cũ `/articles` | `routes.rb` |
| Open redirect sau đăng nhập | Chỉ nhận `redirect` bắt đầu bằng `/` | `login.vue` |
| CSRF | API dùng header `Authorization` (trình duyệt không tự gửi) + cookie `sameSite: lax` | `useAuth.ts` |
| XSS khi hiện nội dung người dùng | Vue tự escape `{{ }}`; dự án không dùng `v-html` | toàn bộ template |
| SQL injection | Chỉ dùng `where(key: value)`/`find`, không ghép chuỗi SQL | models, controllers |

---

## 7. Test

### 7.1 Chạy test

```powershell
cd backend
ruby bin/rails test
```
Kết quả hiện tại: **58 runs, 92 assertions, 0 failures, 0 errors**.

Test chạy trên **database riêng** (`storage/test.sqlite3`), không đụng dữ liệu thật. Mỗi test chạy trong một transaction và bị **hoàn tác** sau khi xong, nên test này không ảnh hưởng test kia.

### 7.2 Fixtures (`test/fixtures/*.yml`): dữ liệu mẫu

```yaml
alice:
  name: Alice
  email: alice@example.com
  password_digest: <%= BCrypt::Password.create("password123") %>
  auth_token: alice-token
  admin: false
```
- Mỗi khối là một dòng trong bảng; `alice` là **tên** để gọi trong test: `users(:alice)`.
- `<%= ... %>`: chạy code Ruby trong file YAML. Ở đây băm mật khẩu `password123` giống cách `has_secure_password` làm.
- Bộ dữ liệu:
  - `users.yml`: `alice` (tác giả), `bob` (thành viên chưa viết gì), `admin`;
  - `articles.yml`: Alice viết 3 bài: `public_post`, `private_post`, `archived_post`;
  - `comments.yml`: Bob và Alice mỗi người 1 comment trên bài public.
- `user: alice` trong articles.yml: Rails tự đổi thành `user_id` của fixture `alice`.

### 7.3 `test/test_helper.rb`

```ruby
parallelize(workers: Gem.win_platform? ? 1 : :number_of_processors)
fixtures :all
...
class ActionDispatch::IntegrationTest
  def auth(user)
    { "Authorization" => "Bearer #{user.auth_token}" }
  end
end
```
- `parallelize`: chạy test song song bằng nhiều tiến trình. Windows không có `fork()` nên đặt 1 worker (chạy lần lượt); Mac/Linux vẫn chạy song song.
- `fixtures :all`: nạp mọi file trong `test/fixtures/`.
- `auth(user)`: tạo header giống hệt cái Nuxt gửi. Dùng: `get "/api/session", headers: auth(users(:alice))`.
  - **(cú pháp)** `"Bearer #{...}"`: chèn giá trị vào chuỗi trong Ruby (chỉ chạy với dấu nháy kép).

### 7.4 Model test (`test/models/`)

Kiểm tra luật trong model, không qua HTTP.
- `user_test.rb` (7 test): hợp lệ khi đủ thông tin; email được cắt khoảng trắng + chữ thường; email sai định dạng bị từ chối; email trùng (khác hoa thường) bị từ chối; tên bắt buộc; mật khẩu ≥ 6; có token khi tạo.
- `article_test.rb` (7 test): mặc định `public`; status lạ bị từ chối; body ≥ 10 ký tự; `visible_to` cho khách / thành viên / tác giả / admin.
- `comment_test.rb` (2 test): body không được trống (kể cả toàn khoảng trắng); phải có user.

Cấu trúc một test:
```ruby
test "email must look like an email" do
  assert_not build(email: "not-an-email").valid?
end
```
- `test "mô tả" do ... end`: một ca kiểm thử.
- `assert_not x`: test **đạt** nếu `x` là false. Còn có `assert`, `assert_equal kỳ_vọng, thực_tế`, `assert_includes`, `assert_difference`...

### 7.5 API test (`test/controllers/api/`): đi đúng đường HTTP như Nuxt

Ví dụ:
```ruby
test "other member cannot edit" do
  patch "/api/articles/#{articles(:public_post).id}", params: { article: { title: "Hacked" } }, headers: auth(users(:bob))
  assert_response :forbidden
end
```
- `patch "/api/..."`: gửi request thật vào app (không cần bật server).
- `assert_response :forbidden`: mã trả về phải là 403.
- `assert_difference("Article.count", -1) do ... end`: sau khối lệnh, số bài phải **giảm đúng 1**. `assert_no_difference`: không được đổi.
- `response.parsed_body`: JSON trả về đã đổi thành hash/mảng Ruby.

**`auth_test.rb`** (9 test): đăng ký trả token dùng được; đăng ký sai trả lỗi đủ 4 ô; không tự làm admin được; JSON đăng ký không lộ `password_digest`; đăng nhập đúng (cả khi gõ email viết hoa); sai mật khẩu và email không tồn tại đều 401; `GET /api/session` có `admin`; không token / token bịa → 401; đăng xuất xong token cũ → 401.

**`articles_controller_test.rb`** (23 test), đi theo từng dòng bảng phân quyền:
- Xem: khách chỉ thấy public; thành viên thêm private; tác giả thêm bài archived của mình; admin thấy hết; bài mới nhất lên đầu; thông tin tác giả chỉ có id + name; khách mở private → 404; thành viên mở archived của người khác → 404; tác giả và admin mở archived → 200; trang bài có comment.
- Tạo: khách → 401; thành viên tạo được, bài thuộc về họ, mặc định public; dữ liệu sai → 422 đủ 3 ô; gửi `user_id` người khác cũng vô ích.
- Sửa: tác giả sửa được; tác giả gửi dữ liệu sai → 422; thành viên khác → 403; **admin → 403**; khách → 401.
- Xóa: thành viên khác → 403; tác giả xóa được và comment bị xóa theo; admin xóa được; khách → 401.

**`comments_controller_test.rb`** (10 test): khách không comment được; tên người comment lấy từ tài khoản dù gửi tên khác; comment rỗng → 422; comment bài private được; không comment được bài không xem được (404); người viết xóa được; **tác giả bài không xóa được comment người khác** (403); admin xóa được; khách không xóa được; id comment phải thuộc đúng bài trên URL (404).

### 7.6 Kiểm thử bằng tay đã chạy (giao diện thật)

Với dữ liệu test `zz-...@x.com` (đã xóa sau khi thử):

| Tình huống | Kết quả |
|---|---|
| Khách vào `/articles/new`, `/articles/1/edit` | 302 → `/login?redirect=...` |
| Đã đăng nhập vào `/login`, `/register` | 302 → `/` |
| Bob / admin mở trang sửa bài của Alice | 403 |
| Alice mở trang sửa bài của mình | 200 |
| Khách / Bob mở bài archived của Alice | 404 |
| Trang chủ theo từng vai | Khách: 1 bài; Bob: + "Thành viên"; Alice, admin: + "Lưu trữ" |
| Nút trên bài public có comment của Bob | Khách: không nút; Bob: 1 (xóa comment mình); Alice: Edit + Destroy bài; admin: Destroy bài + Destroy comment |
| Gửi comment trống | Báo "Nhập nội dung comment", không gửi request |
| Gửi comment | Comment hiện ra, ô nhập trống lại |
| Tạo bài chọn "Thành viên" | Trang bài có thẻ "Thành viên" |
| Đăng ký email trùng (viết hoa) | "Email has already been taken" |
| Đăng xuất | Header về trạng thái khách |
| Console trình duyệt | Không có lỗi hay cảnh báo hydration |

---

## 8. Những gì đã sửa trong đợt dọn dẹp cuối

### 8.1 Bỏ `status` của comment

**Vấn đề (dư lại từ Rails guide):** form comment có ô Status (public/private/archived), nhưng:
- chọn `private` → **không có tác dụng gì**, ai xem được bài vẫn thấy comment;
- chọn `archived` → frontend **giấu** comment đi, nhưng API vẫn trả comment đó cho bất kỳ ai → "giấu" mà không giấu thật;
- người dùng phải chọn một thứ vô nghĩa mỗi lần comment.

**Sửa:** xóa cột `comments.status` (migration), bỏ `include Visible` khỏi `Comment`, bỏ `:status` khỏi `permit`, bỏ ô Status và bộ lọc ở frontend.

**Cách khác đã cân nhắc:** làm cho status comment có tác dụng thật (lọc ở Rails). Không chọn vì blog không cần comment riêng tư: quyền xem comment đi theo quyền xem bài là đủ và dễ hiểu.

### 8.2 Status bài viết: mặc định, bỏ concern `Visible`, nhãn tiếng Việt

**Vấn đề:**
- Cột `status` không có mặc định → gọi API tạo bài không gửi status thì bị lỗi 422 khó hiểu.
- Concern `Visible` (từ Rails guide) có `public_count` và `archived?` không ai dùng; giờ chỉ còn `Article` dùng.
- Ô chọn hiện chữ `public / private / archived`, trong khi "private" thực tế là "thành viên đăng nhập xem được".
- Trang chủ không cho biết bài nào là bài không công khai.

**Sửa:**
- Migration: mặc định `public`, cấm NULL (dòng NULL cũ được điền `public`).
- Đưa `STATUSES` + validate vào thẳng `Article`, xóa `app/models/concerns/visible.rb`.
- `visible_to`: đổi `where("status = 'public'")` (chuỗi SQL) thành `where(status: "public")`, cùng kiểu với các dòng bên dưới.
- Frontend: `utils/articleStatus.ts` với nhãn tiếng Việt; ô "Ai được xem" có mô tả; tag trên trang chủ cho bài không công khai.

### 8.3 Validate còn thiếu ở backend

- `Comment`: `validates :body, presence: true`. Trước đây gửi comment rỗng vẫn lưu được. Frontend cũng thêm rule bắt buộc.
- `User`: email phải đúng định dạng. Trước đây chỉ frontend kiểm tra, gọi thẳng API vẫn đăng ký được email `"abc"`. **Nguyên tắc: không tin dữ liệu từ ngoài vào; validate ở server là bắt buộc, ở trình duyệt chỉ để báo lỗi nhanh.**

### 8.4 Các sửa nhỏ khác

| Chỗ | Cũ | Mới | Vì sao |
|---|---|---|---|
| `ArticlesController#update` | `article = Article.find(params[:id])` rồi sửa `article` | Dùng luôn `@article` | `set_article` đã tìm sẵn; tìm lại là thừa và bỏ qua `visible_to` |
| `ArticlesController#index` | Không sắp xếp (cũ nhất trước) | `.order(created_at: :desc)` | Blog thường hiện bài mới nhất trước |
| Mọi controller | `:unprocessable_entity` | `:unprocessable_content` | Tên cũ bị Rack đánh dấu sắp bỏ, in cảnh báo |
| `formatDate.ts` | Theo múi giờ máy | Cố định `Asia/Ho_Chi_Minh` | Server và trình duyệt in cùng một giờ |
| Fixtures | 2 user trùng email `MyString`, bài không có tác giả | Bộ dữ liệu có nghĩa (alice, bob, admin) | `bin/rails test` lỗi ngay từ đầu |
| `Gemfile` | `minitest 6.1.0` | `minitest < 6` | minitest 6 không chạy được với Rails 7.1 |
| `test_helper.rb` | Luôn chạy song song | 1 worker trên Windows | Windows không có `fork()` |

### 8.5 Những thứ cố ý **không** đổi

- **Cột `commenter`** (tên người comment): giữ lại. Database trên máy cũ có comment từ thời Rails guide, chưa có `user_id`; chúng chỉ còn tên trong `commenter`. Xóa cột này thì mất tên các comment đó.
- **`user_id` cho phép NULL** trong database: cũng vì dữ liệu cũ (bài tạo trước khi có user). Model vẫn bắt buộc có user cho bài và comment mới. Thêm `NOT NULL` sẽ làm migration lỗi trên máy cũ.
- **Token sai ở trang công khai** vẫn được coi là khách thay vì báo 401: frontend đã gọi `GET /api/session` mỗi lần tải trang, API này trả 401 khi token sai, và `fetchUser` tự xóa cookie hỏng. Làm thêm ở backend không thay đổi gì với người dùng.
- **Các gem dành cho HTML** (`importmap`, `turbo`, `stimulus`): không dùng nữa nhưng gỡ ra phải sửa nhiều cấu hình, dễ sinh lỗi trước demo, mà giữ lại cũng không mở lỗ hổng nào.

---

## 9. Kịch bản demo và câu hỏi hay gặp

### 9.1 Kịch bản demo gợi ý (khoảng 10 phút)

Chuẩn bị: tạo 3 tài khoản (ví dụ An - tác giả, Bình - thành viên, Admin) rồi cấp admin:
```powershell
cd backend
ruby bin/rails runner 'User.find_by(email: "admin@example.com").update!(admin: true)'
```
An tạo 3 bài: một "Công khai", một "Thành viên", một "Lưu trữ". Bình comment vào bài công khai.

1. **Kiến trúc** (1 phút): Nuxt cổng 8000 vẽ giao diện, Rails cổng 3000 là API, proxy `/api`.
2. **Khách** (1 phút): trang chủ chỉ thấy bài công khai; vào bài không có nút sửa/xóa; ô comment thay bằng lời mời đăng nhập; gõ `/articles/new` → bị đưa sang đăng nhập.
3. **Đăng nhập Bình** (2 phút): thấy thêm bài "Thành viên" có nhãn cam; không thấy bài "Lưu trữ"; comment được; chỉ có nút xóa comment của mình; gõ URL sửa bài của An → 403.
4. **Đăng nhập An** (2 phút): thấy cả 3 bài với nhãn; sửa bài, "Sửa lần cuối" xuất hiện; không có nút xóa comment của Bình.
5. **Đăng nhập Admin** (1 phút): thấy tất cả; xóa được mọi comment và bài; **không** có nút sửa bài của người khác.
6. **Backend chặn thật** (1 phút): mở terminal gọi thẳng API bằng tài khoản Bình để xóa bài của An → 403. Câu chốt: "Ẩn nút chỉ là giao diện; dù gọi thẳng API vẫn bị chặn."
7. **Test** (1 phút): `ruby bin/rails test` → 58 test pass; giới thiệu file test theo bảng phân quyền.

### 9.2 Câu hỏi hay gặp

**Vì sao không trả 403 khi khách xem bài private mà lại 404?**
Trả 403 là ngầm xác nhận "bài này có tồn tại nhưng bạn không được xem". 404 không tiết lộ gì. GitHub làm y hệt với repo private.

**Vì sao lưu token trong cookie mà không dùng localStorage?**
Vì SSR: server Nuxt cần biết người dùng là ai khi dựng HTML, mà server chỉ đọc được cookie (trình duyệt tự gửi kèm). localStorage chỉ có trong trình duyệt.

**Cookie có bị tấn công CSRF không?**
Rails không đọc cookie; Rails chỉ đọc header `Authorization`, mà trang web khác không tự thêm được header này vào request. Thêm `sameSite: 'lax'` để cookie không đi kèm request ngầm từ trang khác.

**Token có hết hạn không?**
Token không tự hết hạn; nó chỉ mất hiệu lực khi đăng xuất (đổi token). Cookie phía trình duyệt sống 30 ngày. Muốn chặt hơn có thể thêm thời hạn cho token (xem mục 10).

**Mật khẩu lưu thế nào?**
Bcrypt băm một chiều, có "salt" ngẫu nhiên. Không giải ngược được; đăng nhập là băm mật khẩu nhập vào rồi so sánh.

**N+1 query là gì, dự án xử lý ở đâu?**
Lấy 100 bài rồi mỗi bài hỏi database tác giả một lần = 101 câu SQL. `.includes(:user)` gom thành 2 câu.

**Vì sao admin không được sửa bài người khác?**
Đó là quyết định thiết kế trong bảng phân quyền: admin có quyền dọn dẹp (xóa) nhưng không được thay lời người khác. Có test riêng cho luật này.

**Frontend kiểm tra rồi sao backend còn kiểm tra?**
Frontend chạy trên máy người dùng, họ tắt hay sửa được. Backend là lớp duy nhất đáng tin. Frontend chỉ để báo lỗi nhanh và giao diện gọn.

**Vì sao xóa giao diện HTML cũ của Rails?**
Trang `/articles` cũ không dùng `visible_to`: khách xem được cả bài private/archived (đã chứng minh: API trả 404, trang cũ trả 200 có tiêu đề bài). Nó còn dùng mật khẩu Basic Auth chung `dhh/secret` ghi trong code.

---

## 10. Giới hạn và việc còn lại

- **Quên mật khẩu**: chưa làm. Hướng làm: `generates_token_for :password_reset` (Rails 7.1), mailer gửi link, 2 API (`POST`/`PATCH /api/password`), 2 trang Nuxt.
- Token không có thời hạn: có thể thêm cột thời gian và từ chối token quá cũ.
- Chưa giới hạn số lần đăng nhập sai (rate limit); Rails 8 có `rate_limit`, Rails 7.1 cần gem như `rack-attack`.
- Chưa phân trang danh sách bài: ổn với vài chục bài, nhiều bài thì nên thêm.
- Chưa có trang lỗi riêng (`error.vue`): 403/404 đang dùng trang lỗi mặc định của Nuxt.
- Nhỏ: trong `login.vue`, `useRoute()` đang gọi bên trong hàm `submit` sau `await`. Vẫn chạy (đã thử), nhưng thói quen tốt hơn là đặt `const route = useRoute()` ở đầu `<script setup>` rồi dùng `route.query.redirect`.
