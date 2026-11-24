class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    # The link opens the Nuxt page, which sends the token back to PATCH /api/password
    @url = "#{ENV.fetch("FRONTEND_URL", "http://localhost:8000")}/reset-password?token=#{CGI.escape(user.generate_token_for(:password_reset))}"
    # Dev has no real mail server (emails go to tmp/mails, base64-encoded): print the link in the Rails terminal
    Rails.logger.info("[dev] Link đặt lại mật khẩu cho #{user.email}: #{@url}") if Rails.env.development?
    mail to: user.email, subject: "Đặt lại mật khẩu Blog của tôi"
  end
end
