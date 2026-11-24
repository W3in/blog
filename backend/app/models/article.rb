class Article < ApplicationRecord
    # public: everyone, private: logged-in members, archived: only the author and admins
    STATUSES = %w[public private archived]

    # What the editor may produce. Everything else (<script>, onclick=...) is removed before saving
    ALLOWED_TAGS = %w[p br strong em s u h2 h3 ul ol li blockquote pre code a img hr span]
    ALLOWED_ATTRIBUTES = %w[href src alt title target rel width height style]
    # Inside style="": only text color, highlight, font and alignment (no width: 9999px, float, margin...)
    ALLOWED_CSS = %w[color background-color font-family text-align]
    TITLE_MAX = 300

    # Guests read about this many characters, then have to log in
    PREVIEW_LENGTH = 300

    belongs_to :user
    has_many :comments, dependent: :destroy
    has_many :likes, as: :likeable, dependent: :delete_all

    before_validation :sanitize_body

    validates :title, presence: true, length: { maximum: TITLE_MAX }
    validates :status, inclusion: { in: STATUSES }
    validate :body_has_enough_text

    def self.visible_to(user)
        return where(status: "public") unless user
        return all if user.admin?
        where(status: ["public", "private"]).or(where(user: user))
    end

    # Body as plain text, entities decoded ("&amp;" -> "&")
    def plain_text
        text_of(fragment)
    end

    # Short summary for the article list
    def excerpt
        plain_text.truncate(200)
    end

    # First image of the body, shown as a thumbnail in the list
    def cover_image
        fragment.at_css("img")&.[]("src")
    end

    # One card in a list (home page, a user's profile): no body, a plain-text excerpt and the first image instead
    def card_json
        as_json(except: :body, include: { user: User::PUBLIC_JSON })
            .merge("excerpt" => excerpt, "cover_image" => cover_image)
    end

    # What guests get: whole blocks until ~300 characters, so formatting stays and no tag is cut in half.
    # The block that goes over the limit is shortened to plain text ending with "…"
    def preview
        html = +""
        remaining = PREVIEW_LENGTH
        fragment.children.each do |node|
            break if remaining <= 0
            text = node.text
            html << (text.length <= remaining ? node.to_html : "<p>#{ERB::Util.html_escape(text_of(node).first(remaining).rstrip)}…</p>")
            remaining -= text.length
        end
        html
    end

    def preview_truncated?
        fragment.text.length > PREVIEW_LENGTH
    end

    private
        def fragment
            Nokogiri::HTML5.fragment(body.to_s)
        end

        # Text with a space after every block: "<li>a</li><li>b</li>" gives "a b", not "ab",
        # while "<strong>check-in</strong>, và" stays "check-in, và"
        def text_of(node)
            copy = node.dup
            copy.css("p, li, h2, h3, blockquote, pre, br, hr").each { |block| block.add_next_sibling(" ") }
            copy.text.squish
        end

        # Rendered with v-html in Nuxt, so only safe HTML may ever reach the database.
        # Step 1: Rails removes tags/attributes outside the lists and dangerous CSS (url(), expression()...).
        # Step 2: from what is left in style="", keep only the ALLOWED_CSS properties
        def sanitize_body
            return if body.nil?
            doc = Nokogiri::HTML5.fragment(ActionController::Base.helpers.sanitize(body, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES))
            doc.css("[style]").each do |node|
                rules = node["style"].split(";").select { |rule| ALLOWED_CSS.include?(rule.split(":").first.to_s.strip.downcase) }
                rules.empty? ? node.remove_attribute("style") : node["style"] = rules.map(&:strip).join("; ")
            end
            self.body = doc.to_html
        end

        # Count letters, not HTML: "<p></p>" is 7 characters but empty
        def body_has_enough_text
            errors.add(:body, :too_short, count: 10) if plain_text.length < 10
        end
end
