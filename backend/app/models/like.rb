# One heart from one user on one article or comment
class Like < ApplicationRecord
  belongs_to :user
  # polymorphic: likeable is an Article or a Comment (likeable_type says which).
  # counter_cache: keeps likes_count on that article/comment up to date on every create/destroy
  belongs_to :likeable, polymorphic: true, counter_cache: true
  # No uniqueness validation: the unique index on (user, likeable) is the real guard, and
  # LikesController#create relies on it (create_or_find_by!)
end
