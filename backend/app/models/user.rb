class User < ApplicationRecord
    has_secure_password
    has_secure_token :auth_token

    # Reset link token: expires after 15 minutes, and stops working once the password changes (the salt changes)
    generates_token_for :password_reset, expires_in: 15.minutes do
        password_salt&.last(10)
    end

    has_many :articles, dependent: :destroy
    has_many :comments, dependent: :destroy

    normalizes :email, with: ->(e) { e.strip.downcase }
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :name, presence: true
    validates :password, presence: true, length: { minimum: 6 }, allow_nil: true
end
