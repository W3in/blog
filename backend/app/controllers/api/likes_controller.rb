# Hearts on an article (/api/articles/:article_id/like) or a comment (/api/articles/:article_id/comments/:comment_id/like)
class Api::LikesController < Api::BaseController
  before_action :require_login
  before_action :set_likeable

  # POST -> { likes_count, liked: true }. Liking twice is not an error and does not count twice
  def create
    # create_or_find_by!: tries the INSERT; if the unique index says it exists already, finds that row instead
    current_user.likes.create_or_find_by!(likeable: @likeable)
    render_state(true)
  end

  # DELETE -> { likes_count, liked: false }
  def destroy
    # destroy_all, not delete_all: destroy runs the callbacks, so counter_cache lowers likes_count
    current_user.likes.where(likeable: @likeable).destroy_all
    render_state(false)
  end

  private
    # Same visibility rule as reading the article: no hearts on what you cannot see (404)
    def set_likeable
      article = Article.visible_to(current_user).find(params[:article_id])
      @likeable = params[:comment_id] ? article.comments.find(params[:comment_id]) : article
    end

    def render_state(liked)
      render json: { likes_count: @likeable.reload.likes_count, liked: liked }
    end
end
