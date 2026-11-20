class Api::ArticlesController < Api::BaseController
  before_action :require_login, except: [:index, :show]
  before_action :set_article, only: [:show, :update, :destroy]

  # Only id + name of the author: the users table also holds password_digest and auth_token
  AUTHOR_JSON = { only: [:id, :name] }

  def index
    # includes(:user): load all authors in one query instead of one query per article (N+1)
    render json: Article.visible_to(current_user).includes(:user), include: { user: AUTHOR_JSON }
  end

  def show
    render json: @article, include: { comments: {}, user: AUTHOR_JSON }
  end

  def create
    article = current_user.articles.new(article_params)

    if article.save
      render json: article, status: :created
    else
      render json: article.errors, status: :unprocessable_entity
    end
  end

  def update
    return head :forbidden unless @article.user == current_user 

    article = Article.find(params[:id])

    if article.update(article_params)
      render json: article
    else
      render json: article.errors, status: :unprocessable_entity
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
