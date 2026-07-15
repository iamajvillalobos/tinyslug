require "test_helper"

class LinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:alice)
  end

  test "index stays scoped to the current account" do
    get links_path

    assert_response :success
    assert_select "##{dom_id(links(:alice_docs))}"
    assert_select "##{dom_id(links(:bob_docs))}", count: 0
  end

  test "creates a link through the shared operation" do
    assert_difference("accounts(:alice).links.count", 1) do
      post links_path, params: {
        link: {
          destination_url: "https://example.com/new",
          name: "New link",
          tags: "news, product",
          tracking_enabled: "1"
        }
      }
    end

    link = accounts(:alice).links.order(:created_at).last
    assert_redirected_to link_path(link)
    assert_equal %w[news product], link.tags.order(:name).pluck(:name)
  end

  test "reuses an unnamed matching link" do
    assert_no_difference("Link.count") do
      post links_path, params: { link: { destination_url: links(:alice_docs).destination_url } }
    end

    assert_redirected_to link_path(links(:alice_docs))
  end

  test "renders validation errors" do
    post links_path, params: { link: { destination_url: "javascript:alert(1)", slug: "bad_slug" } }

    assert_response :unprocessable_content
    assert_select "[role=alert]"
  end

  test "Turbo creation prepends a row" do
    post links_path,
      params: { link: { destination_url: "https://example.com/turbo", name: "Turbo" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.media_type, "turbo-stream"
    assert_select "turbo-stream[action=prepend][target=links-list]"
  end

  test "updates and destroys an owned link" do
    link = links(:alice_docs)

    patch link_path(link), params: { link: { name: "Updated", tags: "launch" } }
    assert_redirected_to link_path(link)
    assert_equal "Updated", link.reload.name

    assert_difference("Link.count", -1) { delete link_path(link) }
    assert_redirected_to links_path
  end

  test "cross-account member routes return not found" do
    link = links(:bob_docs)

    get link_path(link)
    assert_response :not_found
    sign_in users(:alice)
    get edit_link_path(link)
    assert_response :not_found
    sign_in users(:alice)
    patch link_path(link), params: { link: { name: "Nope" } }
    assert_response :not_found
    sign_in users(:alice)
    get export_link_path(link)
    assert_response :not_found
    sign_in users(:alice)
    get qr_link_path(link, format: :svg)
    assert_response :not_found
    sign_in users(:alice)
    delete link_path(link)
    assert_response :not_found
    assert Link.exists?(link.id)
  end

  test "exports formula-safe CSV" do
    links(:alice_docs).update!(name: "=SUM(1,2)\n\"quoted\"")

    get export_link_path(links(:alice_docs))

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, %Q("'=SUM(1,2)\n""quoted""")
  end

  test "downloads SVG and PNG QR codes" do
    get qr_link_path(links(:alice_docs), format: :svg)
    assert_response :success
    assert_equal "image/svg+xml", response.media_type
    assert_includes response.body, "<svg"

    get qr_link_path(links(:alice_docs), format: :png)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.b.start_with?("\x89PNG".b)
  end
end
