class Api::UsersController < Api::BaseController
  def create
    user = User.new(user_params)

    if user.save
      render json: { token: user.auth_token, user: user.slice(:id, :name, :email) }, status: :created
    else
      render json: user.errors, status: :unprocessable_content
    end
  end

  # GET /api/users/:id -> public profile: name, avatar, join date and the articles this viewer may see
  def show
    user = User.find(params[:id])
    # visible_to: a guest sees this user's public articles only, the same rule as everywhere else
    articles = Article.visible_to(current_user).where(user: user)
      .includes(user: { avatar_attachment: :blob }).order(created_at: :desc)
    render json: user.as_json(only: [:id, :name, :created_at], methods: :avatar_url)
      .merge("articles" => articles.map(&:card_json))
  end

  private
    # No :admin here, so nobody can sign themselves up as admin
    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end
end
