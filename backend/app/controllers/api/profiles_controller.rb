# The logged-in user's own profile. A singular resource (no id in the URL), so nobody can edit someone else's
class Api::ProfilesController < Api::BaseController
  before_action :require_login

  # PATCH /api/profile { profile: { name } } -> the updated user
  def update
    if current_user.update(params.require(:profile).permit(:name))
      render json: current_user.slice(:id, :name, :email, :admin)
    else
      render json: current_user.errors, status: :unprocessable_content
    end
  end

  # PATCH /api/profile/password { password_challenge, password, password_confirmation } -> { token }
  def password
    # password_challenge (Rails 7.1): update fails unless it matches the current password.
    # to_s: a missing challenge is nil, and Rails skips the check for nil
    changed = current_user.update(
      password_challenge: params[:password_challenge].to_s,
      password: params.require(:password),
      password_confirmation: params[:password_confirmation],
      # New token in the same save: logs out every other device. (regenerate_auth_token after it would
      # save again and re-check the challenge against the NEW password, which fails)
      auth_token: User.generate_unique_secure_token
    )
    return render json: current_user.errors, status: :unprocessable_content unless changed

    render json: { token: current_user.auth_token } # this device gets the new token and stays logged in
  end
end
