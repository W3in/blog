# "Someone commented on your article" / "someone replied to your comment". Made by Comment#notify_people
class Notification < ApplicationRecord
  KINDS = %w[comment reply]

  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User"
  belongs_to :comment

  validates :kind, inclusion: { in: KINDS }

  scope :unread, -> { where(read_at: nil) }

  # What the recipient sees. The writer of an anonymous comment stays anonymous here too
  def as_json_for_recipient
    {
      id: id,
      kind: kind,
      read: read_at.present?,
      created_at: created_at,
      actor: comment.anonymous ? nil : actor.as_json(User::PUBLIC_JSON),
      article: { id: comment.article_id, title: comment.article.title },
      comment_id: comment_id,
      excerpt: comment.body.truncate(80)
    }
  end
end
