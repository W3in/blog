class Api::UploadsController < Api::BaseController
  before_action :require_login

  MAX_SIZE = 5.megabytes

  # POST /api/uploads (multipart form, field "file") -> { url } that the editor puts in an <img>
  def create
    file = params[:file]
    return unless (type = accepted_image_type(file, MAX_SIZE)) # nil: the 422 is already rendered

    blob = ActiveStorage::Blob.create_and_upload!(io: file.tempfile, filename: file.original_filename, content_type: type)
    # shortcut: an image uploaded but never kept in an article stays on disk; add a cleanup job if storage grows
    render json: { url: rails_blob_path(blob, only_path: true) }, status: :created
  end
end
