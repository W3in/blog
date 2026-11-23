class Api::UploadsController < Api::BaseController
  before_action :require_login

  MAX_SIZE = 5.megabytes
  # No SVG: it can carry JavaScript
  IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp]

  # POST /api/uploads (multipart form, field "file") -> { url } that the editor puts in an <img>
  def create
    file = params[:file]
    return render json: { file: ["chưa chọn ảnh"] }, status: :unprocessable_content unless file.is_a?(ActionDispatch::Http::UploadedFile)
    return render json: { file: ["tối đa 5MB"] }, status: :unprocessable_content if file.size > MAX_SIZE

    # Look at the file's first bytes, not at the name or the type the browser claims
    type = Marcel::MimeType.for(file.tempfile)
    file.tempfile.rewind # Marcel read the first bytes; start again from 0 so the whole image is stored
    return render json: { file: ["phải là ảnh PNG, JPG, GIF hoặc WebP"] }, status: :unprocessable_content unless IMAGE_TYPES.include?(type)

    blob = ActiveStorage::Blob.create_and_upload!(io: file.tempfile, filename: file.original_filename, content_type: type)
    # shortcut: an image uploaded but never kept in an article stays on disk; add a cleanup job if storage grows
    render json: { url: rails_blob_path(blob, only_path: true) }, status: :created
  end
end
