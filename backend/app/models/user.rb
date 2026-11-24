class User < ApplicationRecord
    has_secure_password
    has_secure_token :auth_token
    # One image per user, stored by Active Storage (removed from disk when replaced or when the user is deleted)
    has_one_attached :avatar

    # What anyone may see about a user, e.g. next to an article or a comment (never email, token or digest)
    PUBLIC_JSON = { only: [:id, :name], methods: :avatar_url }

    # Reset link token: expires after 15 minutes, and stops working once the password or the email changes
    generates_token_for :password_reset, expires_in: 15.minutes do
        [password_salt&.last(10), email]
    end

    has_many :articles, dependent: :destroy
    has_many :comments, dependent: :destroy

    normalizes :email, with: ->(e) { e.strip.downcase }
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :name, presence: true, length: { minimum: 2, maximum: 50 }
    validates :password, presence: true, length: { minimum: 6 }, allow_nil: true

    # /api/files/... link to the avatar (goes through the Nuxt proxy like article images), nil when none
    def avatar_url
        Rails.application.routes.url_helpers.rails_blob_path(avatar, only_path: true) if avatar.attached?
    end

    # What the logged-in user sees about themselves
    def profile_json
        slice(:id, :name, :email, :admin, :created_at).merge(avatar_url: avatar_url)
    end
end
