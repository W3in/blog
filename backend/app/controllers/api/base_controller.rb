class Api::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  private
    def current_user
        @current_user ||= authenticate_with_http_token do |token, options|
            User.find_by(auth_token: token)
        end
    end

    def require_login
        head :unauthorized unless current_user
    end
end