class Api::ArticlesController < Api::BaseController
  before_action :require_login, except: [:index, :show]
  before_action :set_article, only: [:show, :update, :destroy]

  def index
    render json: Article.visible_to(current_user)
  end

  def show
    render json: @article, include: :comments
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
