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
