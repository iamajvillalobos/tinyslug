require "test_helper"

class ErrorPagesTest < ActiveSupport::TestCase
  test "release error pages are present and self-contained" do
    %w[404 422 429 500].each do |status|
      page = Rails.root.join("public", "#{status}.html").read
      assert_includes page, status
      assert_includes page, "tinyslug"
      assert_includes page, "<meta name=\"robots\" content=\"noindex\">"
    end
  end
end
