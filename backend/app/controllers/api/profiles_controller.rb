# The logged-in user's own account. A singular resource (no id in the URL), so nobody can edit someone else's
class Api::ProfilesController < Api::BaseController
  before_action :require_login

  # PATCH /api/profile { profile: { name } } -> the updated user
  def update
    if current_user.update(params.require(:profile).permit(:name))
      render json: current_user.profile_json
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

  # PATCH /api/profile/email { password_challenge, email } -> the updated user
  # Needs the password: someone using a device you left logged in must not be able to take the account over
  # shortcut: the new address is not confirmed by an emailed link; add one if wrong addresses become a problem
  def email
    if current_user.update(password_challenge: params[:password_challenge].to_s, email: params.require(:email))
      render json: current_user.profile_json
    else
      render json: current_user.errors, status: :unprocessable_content
    end
  end

  # DELETE /api/profile { password_challenge } -> 204. Deletes the user with their articles, comments and avatar
  def destroy
    # authenticate, not password_challenge: destroy runs no validations
    if current_user.authenticate(params[:password_challenge].to_s)
      current_user.destroy
      head :no_content
    else
      current_user.errors.add(:password_challenge, :invalid) # same "không đúng" as the other forms
      render json: current_user.errors, status: :unprocessable_content
    end
  end
end
