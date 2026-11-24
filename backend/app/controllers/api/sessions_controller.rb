class Api::SessionsController < Api::BaseController
  before_action :require_login, only: [:show, :destroy]

  def create
    # Takes the same time whether the email exists or not, so it can't be used to probe for emails
    user = User.authenticate_by(email: params[:email], password: params[:password])

    if user
      render json: { token: user.auth_token, user: user.slice(:id, :name, :email) }
    else
      head :unauthorized
    end
  end

  def show
    render json: current_user.profile_json
  end

  def destroy
    current_user.regenerate_auth_token
    head :no_content
  end

end
