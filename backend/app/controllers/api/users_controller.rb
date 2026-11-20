class Api::UsersController < Api::BaseController
  def create
    user = User.new(user_params)

    if user.save
      render json: { token: user.auth_token, user: user.slice(:id, :name, :email) }, status: :created
    else
      render json: user.errors, status: :unprocessable_entity
    end
  end

  private
    # No :admin here, so nobody can sign themselves up as admin
    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end
end
