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
