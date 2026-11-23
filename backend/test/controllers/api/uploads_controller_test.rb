require "test_helper"

class Api::UploadsControllerTest < ActionDispatch::IntegrationTest
  test "guest cannot upload" do
    post "/api/uploads", params: { file: fixture_file_upload("pixel.png", "image/png") }
    assert_response :unauthorized
  end

  test "member uploads an image and gets a link that serves the same bytes" do
    post "/api/uploads", params: { file: fixture_file_upload("pixel.png", "image/png") }, headers: auth(users(:bob))
    assert_response :created
    url = response.parsed_body["url"]
    assert url.start_with?("/api/files/blobs/proxy/")

    get url
    assert_response :ok
    assert_equal "image/png", response.media_type
    assert_equal file_fixture("pixel.png").binread, response.body
  end

  test "a text file named .png is rejected: the bytes decide, not the name" do
    assert_no_difference("ActiveStorage::Blob.count") do
      post "/api/uploads", params: { file: fixture_file_upload("fake.png", "image/png") }, headers: auth(users(:bob))
    end
    assert_response :unprocessable_content
  end

  test "missing file is a 422, not a crash" do
    post "/api/uploads", params: { file: "just a string" }, headers: auth(users(:bob))
    assert_response :unprocessable_content
  end
end
