class Api::ArticlesController < Api::BaseController
  before_action :require_login, except: [:index, :show]
  before_action :set_article, only: [:show, :update, :destroy]

  def index
    # includes: load all authors and their avatars in a few queries instead of a few per article (N+1)
    articles = Article.visible_to(current_user).includes(user: { avatar_attachment: :blob }).order(created_at: :desc)
    # No body in the list: guests must not read whole articles here, and a summary is all the list shows
    render json: articles.map(&:card_json)
  end

  def show
    # User::PUBLIC_JSON: only id, name, avatar of the author (the users table also holds email, token, digest)
    json = @article.as_json(include: { user: User::PUBLIC_JSON })
    if current_user
      comments = @article.comments.includes(user: { avatar_attachment: :blob }).order(:created_at).map { |comment| comment.as_json_for(current_user) }
      json.merge!("comments" => comments, "truncated" => false)
    else
      # Guests: only the beginning, no comments (comments_count still tells how many there are)
      json.merge!("body" => @article.preview, "truncated" => @article.preview_truncated?)
    end
    render json: json
  end

  def create
    article = current_user.articles.new(article_params)

    if article.save
      render json: article, status: :created
    else
      render json: article.errors, status: :unprocessable_content
    end
  end

  def update
    return head :forbidden unless @article.user == current_user

    if @article.update(article_params)
      render json: @article
    else
      render json: @article.errors, status: :unprocessable_content
    end
  end
  
  def destroy
    return head :forbidden unless @article.user == current_user || current_user.admin?
    @article.destroy
    head :no_content
  end


  private
    def set_article
      @article = Article.visible_to(current_user).find(params[:id])
    end

    def article_params
      params.require(:article).permit(:title, :body, :status)
    end

end
