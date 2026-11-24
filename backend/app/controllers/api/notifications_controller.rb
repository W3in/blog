class Api::NotificationsController < Api::BaseController
  before_action :require_login

  # GET /api/notifications -> { unread_count, items: the 30 newest }
  def index
    items = current_user.notifications
      .includes(actor: { avatar_attachment: :blob }, comment: :article) # avoid N+1 for names, avatars, titles
      .order(created_at: :desc).limit(30)
    render json: { unread_count: current_user.notifications.unread.count, items: items.map(&:as_json_for_recipient) }
  end

  # POST /api/notifications/read -> 204, everything marked as read (when the bell is opened)
  def read
    # update_all: one UPDATE for all rows, no need to load them
    current_user.notifications.unread.update_all(read_at: Time.current)
    head :no_content
  end
end
