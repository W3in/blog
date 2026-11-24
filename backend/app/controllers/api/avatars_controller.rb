class Api::AvatarsController < Api::BaseController
  before_action :require_login

  # The browser already crops it to a small square; this limit stops anyone who skips the browser
  MAX_SIZE = 2.megabytes

  # PUT /api/profile/avatar (multipart form, field "file") -> the updated user
  def update
    file = params[:file]
    return unless (type = accepted_image_type(file, MAX_SIZE)) # nil: the 422 is already rendered

    # has_one_attached: attaching a new image replaces the old one, which Active Storage deletes from disk
    current_user.avatar.attach(io: file.tempfile, filename: file.original_filename, content_type: type)
    render json: current_user.profile_json
  end

  # DELETE /api/profile/avatar -> back to the coloured initial
  def destroy
    current_user.avatar.purge # delete the attachment row, the blob row and the file
    render json: current_user.profile_json
  end
end
