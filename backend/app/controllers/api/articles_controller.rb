class Api::ArticlesController < Api::BaseController
  before_action :require_login, except: [:index, :show]
  before_action :set_article, only: [:show, :update, :destroy]

  PER_PAGE = 10

  def index
    # Search goes on top of visible_to: it can only narrow what this viewer may see, never widen it
    articles = Article.visible_to(current_user)
    articles = articles.search(params[:q]) if params[:q].present?

    # Missing, "abc", "0", "-3" -> page 1; the upper bound stops an absurd number
    page = params[:page].to_i.clamp(1, 100_000)
    # id breaks ties: articles with the same created_at keep one fixed order, so none shows on two pages
    items = articles.includes(user: { avatar_attachment: :blob })
                    .order(created_at: :desc, id: :desc)
                    .limit(PER_PAGE).offset((page - 1) * PER_PAGE)

    render json: {
      items: items.map(&:card_json),
      total: articles.count, # every match, not just this page: the page buttons need it
      page: page,
      per_page: PER_PAGE
    }
  end
  def show
    # User::PUBLIC_JSON: only id, name, avatar of the author (the users table also holds email, token, digest)
    json = @article.as_json(methods: :slug, except: :search_title , include: { user: User::PUBLIC_JSON })
    if current_user
      comments = @article.comments.includes(user: { avatar_attachment: :blob }).order(:created_at)
      # Which of these this viewer hearted: one query for all comments, kept as a Set for fast include?
      liked = current_user.likes.where(likeable: comments).pluck(:likeable_id).to_set
      json.merge!(
        # Flat list in time order with parent_id: the browser builds the reply tree
        "comments" => comments.map { |comment| comment.as_json_for(current_user, liked: liked.include?(comment.id)) },
        "liked" => current_user.likes.exists?(likeable: @article),
        "truncated" => false
      )
    else
      # Guests: only the beginning, no comments (comments_count still tells how many there are)
      json.merge!("body" => @article.preview, "truncated" => @article.preview_truncated?)
    end
    render json: json
  end

  def create
    article = current_user.articles.new(article_params)

    if article.save
      render json: article.as_json(methods: :slug, except: :search_title), status: :created
    else
      render json: article.errors, status: :unprocessable_content
    end
  end

  def update
    return head :forbidden unless @article.user == current_user

    if @article.update(article_params)
      render json: @article.as_json(methods: :slug, except: :search_title)
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
