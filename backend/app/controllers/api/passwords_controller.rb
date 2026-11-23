class Api::PasswordsController < Api::BaseController
  # POST /api/password { email } -> send a reset link
  def create
    user = User.find_by(email: params[:email])
    # deliver_later: queue the email and answer at once, otherwise a slower reply would reveal the email exists
    PasswordsMailer.reset(user).deliver_later if user
    # Same answer whether the email exists or not, so nobody can probe which emails are registered
    head :accepted
  end

  # PATCH /api/password { token, password, password_confirmation } -> set the new password
  def update
    user = User.find_by_token_for(:password_reset, params[:token])
    return render json: { token: ["không hợp lệ hoặc đã hết hạn"] }, status: :unprocessable_content unless user

    # require: a missing/empty password is a 400, otherwise update({}) would "succeed" without changing anything
    if user.update(password: params.require(:password), password_confirmation: params[:password_confirmation])
      user.regenerate_auth_token # log out every device that was logged in with the old password
      head :no_content
    else
      render json: user.errors, status: :unprocessable_content
    end
  end
end
