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

    # No SVG: it can carry JavaScript
    IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp]

    # Uploaded image check shared by editor images and avatars. Returns the real type, or renders a 422 and
    # returns nil. The type comes from the first bytes, not from the file name or what the browser claims
    def accepted_image_type(file, max_size)
        error =
            if !file.is_a?(ActionDispatch::Http::UploadedFile) then "chưa chọn ảnh"
            elsif file.size > max_size then "tối đa #{max_size / 1.megabyte}MB"
            else
                type = Marcel::MimeType.for(file.tempfile)
                file.tempfile.rewind # Marcel read the first bytes; start again from 0 so the whole image is stored
                return type if IMAGE_TYPES.include?(type)
                "phải là ảnh PNG, JPG, GIF hoặc WebP"
            end
        render json: { file: [error] }, status: :unprocessable_content
        nil
    end
end