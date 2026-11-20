class Article < ApplicationRecord
    include Visible
    belongs_to :user
    has_many :comments, dependent: :destroy

    validates :title, presence: true
    validates :body, presence: true, length: { minimum: 10 }

    def self.visible_to(user)
        return where("status = 'public'") unless user
        return all if user.admin?
        where(status: ['public', 'private']).or(where(user: user))
    end

end
