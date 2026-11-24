class Api::CommentsController < Api::BaseController
  before_action :require_login

  def create
    article = Article.visible_to(current_user).find(params[:article_id])
    comment = article.comments.new(comment_params.merge(user: current_user, commenter: current_user.name))

    if comment.save
      render json: comment.as_json_for(current_user), status: :created
    else
      render json: comment.errors, status: :unprocessable_content
    end
  end

  def destroy
    comment = Article.visible_to(current_user).find(params[:article_id]).comments.find(params[:id])
    return head :forbidden unless comment.user == current_user || current_user.admin?
    comment.remove! # emptied instead of deleted when it has replies (Comment#remove!)
    head :no_content
  end

  private
    def comment_params
      # parent_id: the comment being answered. Comment checks it belongs to this article
      params.require(:comment).permit(:body, :anonymous, :parent_id)
    end
end
