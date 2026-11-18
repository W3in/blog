class Api::CommentsController < ActionController::API
  def create
    article = Article.find(params[:article_id])
    comment = article.comments.new(comment_params)

    if comment.save
      render json: comment, status: :created
    else
      render json: comment.errors, status: :unprocessable_entity
    end
  end

  def destroy
    Article.find(params[:article_id]).comments.find(params[:id]).destroy
    head :no_content
  end

  private
    def comment_params
      params.require(:comment).permit(:commenter, :body, :status)
    end
end
