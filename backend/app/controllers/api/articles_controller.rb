class Api::ArticlesController < Api::BaseController
  before_action :require_login, except: [:index, :show]
  before_action :set_article, only: [:show, :update, :destroy]

  # Only id + name of the author: the users table also holds password_digest and auth_token
  AUTHOR_JSON = { only: [:id, :name] }

  def index
    # includes(:user): load all authors in one query instead of one query per article (N+1)
    articles = Article.visible_to(current_user).includes(:user).order(created_at: :desc)
    # No body in the list: guests must not read whole articles here, and a summary is all the list shows
    render json: articles.map { |article|
      article.as_json(except: :body, include: { user: AUTHOR_JSON })
        .merge("excerpt" => article.excerpt, "cover_image" => article.cover_image)
    }
  end

  def show
    json = @article.as_json(include: { user: AUTHOR_JSON })
    if current_user
      comments = @article.comments.includes(:user).order(:created_at).map { |comment| comment.as_json_for(current_user) }
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
