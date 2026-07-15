require "test_helper"

class PublicLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_setting = Rails.configuration.x.public_shortener_enabled
    Public::LinksController::RATE_LIMIT_STORE.clear
  end

  teardown do
    Rails.configuration.x.public_shortener_enabled = @original_setting
    Public::LinksController::RATE_LIMIT_STORE.clear
  end

  test "is unavailable by default" do
    Rails.configuration.x.public_shortener_enabled = false

    get public_shortener_path
    assert_response :not_found
    post public_shortener_path, params: { link: { destination_url: "https://example.com" } }
    assert_response :not_found
  end

  test "creates an untracked and uneditable public link" do
    Rails.configuration.x.public_shortener_enabled = true

    assert_difference("Link.public_shortener.count", 1) do
      post public_shortener_path, params: { link: { destination_url: "https://example.com/public" } }
    end

    assert_response :created
    link = Link.public_shortener.last
    assert_not link.tracking_enabled?
    assert_nil link.custom_domain
    assert_not link.account.user

    sign_in users(:alice)
    get edit_link_path(link)
    assert_response :not_found
  end

  test "returns a small explicit JSON response" do
    Rails.configuration.x.public_shortener_enabled = true

    post public_shortener_path,
      params: { link: { destination_url: "https://example.com/public" } },
      as: :json

    assert_response :created
    assert_equal [ "short_url" ], response.parsed_body.fetch("link").keys
  end

  test "rate limits repeated creation by a digested IP key" do
    Rails.configuration.x.public_shortener_enabled = true

    10.times do |index|
      post public_shortener_path, params: { link: { destination_url: "https://example.com/#{index}" } }
      assert_response :created
    end

    post public_shortener_path, params: { link: { destination_url: "https://example.com/limited" } }
    assert_response :too_many_requests
  end
end
