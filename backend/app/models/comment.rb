class Comment < ApplicationRecord
  # What a comment that had replies shows once its writer deleted it (the replies keep their place)
  DELETED_BODY = "[đã xóa]"

  belongs_to :user
  # counter_cache: keeps articles.comments_count up to date on every create/destroy
  belongs_to :article, counter_cache: true
  # Replies: parent_id points to another comment of the same table (null = top-level comment)
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy
  # as: :likeable: the "likeable" side of the polymorphic Like (Article has the same line)
  has_many :likes, as: :likeable, dependent: :delete_all
  has_many :notifications, dependent: :delete_all

  validates :body, presence: true
  validate :parent_is_a_live_comment_of_this_article

  # After the INSERT is committed (not before: a rolled-back comment must not notify anyone)
  after_create_commit :notify_people

  def deleted?
    deleted_at.present?
  end

  # Reddit-style removal: with replies, empty it and keep it so the thread still makes sense; without, delete it
  def remove!
    return destroy! unless replies.exists?

    update!(body: DELETED_BODY, deleted_at: Time.current)
    notifications.delete_all
  end

  # What a viewer may see. An anonymous comment never sends its writer's name or id, not even to admins;
  # a deleted one sends no writer and no text. liked: whether this viewer gave it a heart (the controller knows)
  def as_json_for(viewer, liked: false)
    hidden = anonymous || deleted?
    {
      id: id,
      parent_id: parent_id,
      body: deleted? ? nil : body,
      deleted: deleted?,
      anonymous: anonymous,
      commenter: hidden ? nil : commenter,     # the name when it was written
      current_name: hidden ? nil : user&.name, # the name now, shown on hover when it differs
      avatar_url: hidden ? nil : user&.avatar_url,
      user_id: hidden ? nil : user_id,
      created_at: created_at,
      likes_count: likes_count,
      liked: liked,
      # Same rule as CommentsController#destroy, decided here so the browser never needs the writer's id
      can_destroy: !deleted? && viewer.present? && (user_id == viewer.id || viewer.admin?)
    }
  end

  private
    # A reply must answer a comment of the same article that still exists (not one emptied by remove!)
    def parent_is_a_live_comment_of_this_article
      return unless parent
      errors.add(:parent, :invalid) if parent.article_id != article_id || parent.deleted?
    end

    # A reply tells the writer of the comment it answers; a top-level comment tells the article's author.
    # Nobody is told about their own comment, and deleted accounts get nothing
    def notify_people
      recipient = parent ? parent.user : article.user
      return if recipient.nil? || recipient == user || recipient.deleted

      Notification.create!(recipient: recipient, actor: user, comment: self, kind: parent ? "reply" : "comment")
    end
end
