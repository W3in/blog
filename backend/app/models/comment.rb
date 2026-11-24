class Comment < ApplicationRecord
  belongs_to :user
  # counter_cache: keeps articles.comments_count up to date on every create/destroy
  belongs_to :article, counter_cache: true

  validates :body, presence: true

  # What a viewer may see. An anonymous comment never sends its writer's name or id, not even to admins
  def as_json_for(viewer)
    {
      id: id,
      body: body,
      anonymous: anonymous,
      commenter: anonymous ? nil : commenter,     # the name when it was written
      current_name: anonymous ? nil : user&.name, # the name now, shown on hover when it differs
      avatar_url: anonymous ? nil : user&.avatar_url,
      user_id: anonymous ? nil : user_id,
      created_at: created_at,
      # Same rule as CommentsController#destroy, decided here so the browser never needs the writer's id
      can_destroy: viewer.present? && (user_id == viewer.id || viewer.admin?)
    }
  end
end
