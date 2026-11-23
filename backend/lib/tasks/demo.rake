# Demo articles to try the app: bin/rails demo:articles  (or EMAIL=ban@vidu.com bin/rails demo:articles)
# Docker: docker compose exec backend bin/rails demo:articles
# Safe to run again: an article whose title already exists is skipped.
namespace :demo do
  desc "Create 3 demo articles: a long public one (guests read the start), a 300-character title, an illustrated travel post"
  task articles: :environment do
    author = ENV["EMAIL"] ? User.find_by(email: ENV["EMAIL"]) : (User.find_by(admin: true) || User.order(:id).first)
    abort "Không tìm thấy tác giả: đăng ký một tài khoản trước, hoặc kiểm tra EMAIL=..." unless author

    DemoArticles.all.each do |attrs|
      if Article.exists?(title: attrs[:title])
        puts "Bỏ qua (đã có): #{attrs[:title].truncate(60)}"
      else
        # body may be a lambda: then it runs (and uploads its images) only now
        body = attrs[:body].respond_to?(:call) ? attrs[:body].call : attrs[:body]
        article = author.articles.create!(attrs.merge(body: body))
        puts "Đã tạo ##{article.id}: #{article.title.truncate(60)}"
      end
    end
    puts "Tác giả: #{author.email}"
  end
end

module DemoArticles
  module_function

  def all
    [long_article, long_title_article, travel_article]
  end

  # Put a picture from db/demo/ into Active Storage and return the URL the editor would have used
  def image_url(file)
    path = Rails.root.join("db/demo", file)
    blob = ActiveStorage::Blob.create_and_upload!(io: File.open(path), filename: file, content_type: "image/jpeg")
    Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
  end

  # --- 1. Long public article: guests only see the first ~300 characters ---
  def long_article
    { title: "Nhật ký 30 ngày tự học Rails và Nuxt: từ con số 0 tới một blog chạy thật", status: "public", body: <<~HTML }
      <p>Ba mươi ngày trước, mình chưa từng viết một dòng Ruby nào. Hôm nay, blog bạn đang đọc chạy bằng Rails ở phía sau và Nuxt ở phía trước, có đăng nhập, phân quyền, trình soạn thảo, ảnh và cả Docker. Đây là toàn bộ hành trình, kể cả những lần ngồi nhìn màn hình đỏ lòm lỗi mà không hiểu vì sao.</p>
      <p>Bài này dài. Nếu bạn chỉ thấy vài dòng đầu thì đó là cố ý: phần còn lại dành cho thành viên. Đăng nhập là đọc được hết.</p>
      <h2>Tuần 1: Rails, và cảm giác "nó tự làm hết à?"</h2>
      <p>Mọi người hay nói Rails là "convention over configuration". Mình chỉ thực sự hiểu câu đó khi gõ <code>bin/rails generate scaffold Article title:string body:text</code> và nhận về cả model, controller, view, migration lẫn route. Rails đoán gần như mọi thứ từ tên: bảng <code>articles</code>, class <code>Article</code>, file <code>articles_controller.rb</code>.</p>
      <p>Cái khó của tuần đầu không phải cú pháp mà là biết thứ gì nằm ở đâu. Mình vẽ lại một bản đồ nhỏ và dán cạnh màn hình:</p>
      <ul>
        <li><strong>Model</strong> (<code>app/models</code>): dữ liệu và luật của dữ liệu, ví dụ "tiêu đề không được trống".</li>
        <li><strong>Controller</strong> (<code>app/controllers</code>): nhận request, gọi model, trả kết quả.</li>
        <li><strong>Migration</strong> (<code>db/migrate</code>): lịch sử thay đổi cấu trúc database, chạy theo thứ tự thời gian.</li>
        <li><strong>Route</strong> (<code>config/routes.rb</code>): URL nào đi vào controller nào.</li>
      </ul>
      <blockquote><p>Bài học đầu tiên: đừng sửa một migration đã chạy. Hãy viết migration mới, hoặc rollback cho sạch nếu đó chỉ là dữ liệu thử.</p></blockquote>
      <h2>Tuần 2: Đăng nhập không cần thư viện</h2>
      <p>Mình định cài Devise, nhưng rồi quyết định tự làm để hiểu. Hóa ra Rails đã có sẵn gần hết: <code>has_secure_password</code> lo mã hóa mật khẩu bằng bcrypt, <code>has_secure_token</code> sinh token ngẫu nhiên, còn <code>authenticate_by</code> so mật khẩu mà không để lộ email nào tồn tại qua thời gian phản hồi.</p>
      <pre><code>class Api::BaseController &lt; ActionController::API
        include ActionController::HttpAuthentication::Token::ControllerMethods

        def current_user
          @current_user ||= authenticate_with_http_token { |token, _| User.find_by(auth_token: token) }
        end
      end</code></pre>
      <p>Toán tử <code>||=</code> nghĩa là "nếu chưa có thì tính, có rồi thì dùng lại". Trong một request, dù gọi <code>current_user</code> mười lần thì database cũng chỉ bị hỏi một lần.</p>
      <h2>Tuần 3: Phân quyền, chỗ dễ sai nhất</h2>
      <p>Viết chức năng thì nhanh, viết đúng luật "ai được làm gì" mới mệt. Mình tự đặt ra một bảng: khách xem bài công khai, thành viên xem thêm bài nội bộ, tác giả sửa bài của mình, admin xóa được mọi thứ nhưng <em>không</em> được sửa bài người khác. Rồi viết test cho từng ô của bảng.</p>
      <p>Có hai nguyên tắc mình rút ra:</p>
      <ol>
        <li><strong>Backend mới là người gác cổng.</strong> Ẩn nút trên giao diện chỉ để gọn mắt; ai cũng gọi thẳng API được.</li>
        <li><strong>Không cho xem thì trả 404, không cho làm thì trả 403.</strong> Trả 403 cho bài riêng tư là vô tình thừa nhận "bài này có tồn tại".</li>
      </ol>
      <h2>Tuần 4: Nuxt, SSR và những lỗi hydration</h2>
      <p>Nuxt render trang trên server rồi gửi HTML xuống, sau đó Vue "tiếp quản" trong trình duyệt. Nếu server và trình duyệt vẽ ra hai thứ khác nhau, ví dụ giờ theo hai múi giờ khác nhau, Vue sẽ cảnh báo hydration mismatch. Cách sửa: cố định múi giờ <code>Asia/Ho_Chi_Minh</code> khi in ngày tháng, và cho các ô chọn của Ant Design một <code>id</code> cố định.</p>
      <p>Token đăng nhập được giữ trong cookie thay vì localStorage, vì cookie đi kèm request lên server, nên trang render trên server cũng biết bạn là ai.</p>
      <h2>Những thứ mình ước đã biết sớm hơn</h2>
      <ul>
        <li>Đọc lỗi từ dòng đầu tiên, không phải dòng cuối. Ruby thường nói rất rõ file nào, dòng nào.</li>
        <li><code>where (status: "public")</code> có dấu cách trước ngoặc là lỗi cú pháp. Một dấu cách làm mình mất nửa buổi tối.</li>
        <li>Không bao giờ <code>render json: user</code>: nó gửi luôn mật khẩu đã mã hóa và token ra ngoài.</li>
        <li>Viết test trước khi sửa phân quyền. Test đỏ lên ngay khi lỡ tay mở cửa sai chỗ.</li>
      </ul>
      <h2>Tiếp theo</h2>
      <p>Blog đã chạy được trong Docker và có thể đưa lên một máy chủ thật. Việc tiếp theo trong danh sách là thông báo khi có người bình luận, rồi có lẽ là tìm kiếm bài viết. Nếu bạn cũng đang tự học, hãy viết nhật ký như thế này: ba tháng sau đọc lại, bạn sẽ bất ngờ vì mình đã đi xa đến đâu.</p>
    HTML
  end

  # --- 2. Title of exactly Article::TITLE_MAX (300) characters: how do cards and pages cope? ---
  def long_title_article
    title = "Bài thử tiêu đề dài đúng 300 ký tự: người viết quá hào hứng nên nhét cả chuyến đi vào tiêu đề, " \
            "từ chuyến xe đêm lên Đà Lạt, ly cà phê sữa nóng lúc năm giờ sáng, đồi chè Cầu Đất xanh mướt, chợ đêm đông nghịt, " \
            "tới bài học rằng tiêu đề nên ngắn, nhưng giao diện vẫn phải chịu được tiêu đề dài thế này!!!"
    raise "Tiêu đề mẫu phải đúng #{Article::TITLE_MAX} ký tự, đang là #{title.length}" unless title.length == Article::TITLE_MAX

    { title: title, status: "public", body: <<~HTML }
      <p>Bài này chỉ để thử giao diện với tiêu đề dài tối đa: <strong>#{Article::TITLE_MAX} ký tự</strong>, giới hạn mà Rails kiểm tra và ô nhập tiêu đề đếm ngược.</p>
      <p>Hãy xem tiêu đề xuống dòng thế nào ở trang chủ, ở đây và trên điện thoại. Không được tràn khung hay đẩy ảnh nhỏ ra ngoài.</p>
    HTML
  end

  # --- 3. Travel post with pictures, fonts, colors, highlights and centered captions ---
  # body is a lambda: the 4 images are uploaded only when this article is really created
  def travel_article
    { title: "Đà Lạt 3 ngày 2 đêm: săn mây đồi thông, lạc giữa đồi chè và chợ đêm lung linh", status: "public", body: -> {
      sunrise, lake, tea, market = %w[1-binh-minh-doi-thong.jpg 2-ho-xuan-huong.jpg 3-doi-che-cau-dat.jpg 4-cho-dem.jpg].map { |f| image_url(f) }
      heading = ->(text) { %(<h2><span style="font-family: 'Playfair Display', serif; color: #0c8599">#{text}</span></h2>) }
      caption = ->(text) { %(<p style="text-align: center"><em><span style="color: #868e96">#{text}</span></em></p>) }
      read = ->(html) { %(<p><span style="font-family: 'Lora', serif">#{html}</span></p>) }
      tip = ->(text) { %(<p><span style="background-color: #fff3bf"><strong>Mẹo nhỏ:</strong> #{text}</span></p>) }

      <<~HTML
        <h2 style="text-align: center"><span style="font-family: 'Dancing Script', cursive; color: #c2255c">“Thành phố này không vội, nên mình cũng chẳng vội.”</span></h2>
        <p><img src="#{sunrise}" alt="Bình minh trên đồi thông Đà Lạt"></p>
        #{caption.call("Năm giờ rưỡi sáng, mây còn nằm ngủ trên những rặng đồi phía xa.")}
        #{read.call("Có những chuyến đi để <strong>check-in</strong>, và có những chuyến đi để thở chậm lại. Đà Lạt với mình là kiểu thứ hai: buổi sáng se lạnh, ly cà phê nóng trong tay, và một lịch trình cố tình để trống thật nhiều.")}
        #{read.call("Dưới đây là lịch trình 3 ngày 2 đêm mình đã đi, kèm chi phí ước tính và vài mẹo nhỏ. Giá chỉ để tham khảo, tùy mùa sẽ khác.")}
        #{heading.call("Ngày 1 · Săn mây trên đồi thông")}
        #{read.call("Xe đêm từ Sài Gòn tới nơi lúc gần bốn giờ sáng, mình đi thẳng lên đồi để kịp đón bình minh. Sương dày tới mức đứng cách vài mét đã không thấy nhau, rồi mặt trời lên, từng lớp mây trôi lững thững qua những rặng thông.")}
        #{tip.call("mang theo áo khoác dày và một đôi tất. Nhiệt độ lúc rạng sáng có thể xuống dưới 15°C, gió trên đồi còn lạnh hơn.")}
        #{read.call("Chiều đến, đi bộ một vòng <span style=\"color: #1971c2\"><strong>hồ Xuân Hương</strong></span> lúc hoàng hôn. Đèn bên hồ bật lên từng ngọn một, mặt nước in bóng hàng thông như một bức tranh.")}
        <p><img src="#{lake}" alt="Hồ Xuân Hương lúc hoàng hôn" width="560" height="315"></p>
        #{caption.call("Hồ Xuân Hương lúc chập choạng tối: ảnh nhỏ hơn bằng cách kéo góc ảnh trong trình soạn thảo.")}
        #{heading.call("Ngày 2 · Lạc giữa đồi chè Cầu Đất")}
        #{read.call("Đồi chè cách trung tâm chừng 25km, đi xe máy khoảng một tiếng. Những luống chè uốn lượn theo sườn đồi như ai đó lấy bút chì kẻ lên mặt đất, càng nhìn càng thấy mình nhỏ bé.")}
        <p><img src="#{tea}" alt="Những luống chè ở Cầu Đất"></p>
        #{caption.call("Con đường đất đỏ chạy xuyên qua đồi chè, ảnh để rộng bằng cả cột chữ.")}
        <blockquote><p><span style="font-family: 'Dancing Script', cursive; color: #2f9e44">Đi chậm thôi, vì đẹp nhất là những khúc cua mình chưa kịp đặt tên.</span></p></blockquote>
        #{tip.call("đi sớm trước 8 giờ để có nắng đẹp và tránh đông người. Nhớ hỏi chủ vườn trước khi đi vào giữa luống chè.")}
        #{heading.call("Ngày 3 · Chợ đêm và vị ngọt của Đà Lạt")}
        #{read.call("Tối cuối, mình xuống <span style=\"background-color: #ffe3e3\">chợ đêm</span>. Dây đèn nhiều màu giăng ngang trời, mùi bắp nướng, khoai lang nướng, sữa đậu nành nóng quyện vào nhau. Một ly sữa đậu nành và cái bánh tráng nướng là đủ ấm người.")}
        <p><img src="#{market}" alt="Chợ đêm Đà Lạt" width="480" height="270"></p>
        #{caption.call("Chợ đêm lên đèn: ảnh cỡ “Vừa” trong thanh công cụ.")}
        <h3><span style="font-family: 'Playfair Display', serif">Nên mang gì?</span></h3>
        <ul>
          <li><strong>Áo khoác</strong>, khăn quàng và tất: tối và sáng đều lạnh.</li>
          <li><strong>Giày đế bám</strong>: đường đồi có đoạn trơn khi có sương.</li>
          <li><strong>Pin dự phòng</strong>: chụp ảnh nhiều, trời lạnh pin tụt nhanh.</li>
        </ul>
        <h3><span style="font-family: 'Playfair Display', serif">Chi phí ước tính cho một người</span></h3>
        <ol>
          <li>Xe giường nằm khứ hồi: <span style="color: #e8590c"><strong>khoảng 600.000đ</strong></span></li>
          <li>Homestay 2 đêm: <span style="color: #e8590c"><strong>khoảng 700.000đ</strong></span></li>
          <li>Thuê xe máy 2 ngày: <span style="color: #e8590c"><strong>khoảng 300.000đ</strong></span></li>
          <li>Ăn uống, cà phê, vé tham quan: <span style="color: #e8590c"><strong>khoảng 900.000đ</strong></span></li>
        </ol>
        <p style="text-align: center"><span style="background-color: #d3f9d8"><strong>Tổng cộng: khoảng 2.500.000đ</strong></span> <span style="color: #868e96">(chưa tính mua quà)</span></p>
        <hr>
        <h3 style="text-align: center"><span style="font-family: 'Dancing Script', cursive; color: #6741d9">Hẹn gặp lại Đà Lạt, vào một sáng có mây.</span></h3>
      HTML
    } }
  end
end
