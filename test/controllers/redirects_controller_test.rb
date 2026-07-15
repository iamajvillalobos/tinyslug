require "test_helper"

class RedirectsControllerTest < ActionDispatch::IntegrationTest
  CHROME_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
  BOT_USER_AGENT = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

  test "redirects a primary-domain slug without fetching its destination" do
    links(:alice_docs).update!(destination_url: "http://127.0.0.1:1/service-is-not-running")
    host! "localhost"

    get short_link_path(links(:alice_docs).slug)

    assert_response :found
    assert_redirected_to links(:alice_docs).destination_url
  end

  test "returns not found for an unknown primary slug" do
    host! "localhost"

    get short_link_path("missing-link")

    assert_response :not_found
  end

  test "verified custom hosts resolve only their own links" do
    host! custom_domains(:alice_verified).hostname

    get short_link_path(links(:alice_custom).slug)
    assert_redirected_to links(:alice_custom).destination_url

    get short_link_path(links(:alice_docs).slug)
    assert_response :not_found
  end

  test "unverified and unknown custom hosts never resolve" do
    host! custom_domains(:alice_pending).hostname
    get short_link_path(links(:alice_custom).slug)
    assert_response :not_found

    host! "unknown.example.test"
    get short_link_path(links(:alice_custom).slug)
    assert_response :not_found
  end

  test "specific application routes take precedence over slugs" do
    host! "localhost"
    get rails_health_check_path
    assert_response :success

    get new_user_session_path
    assert_response :success
  end

  test "enqueues only a privacy-safe derived visit payload" do
    link = links(:alice_docs)
    link.update!(tracking_enabled: true)
    host! "localhost"
    user_agent = CHROME_USER_AGENT

    assert_enqueued_with(job: RecordVisitJob) do
      get short_link_path(link.slug), headers: {
        "User-Agent" => user_agent,
        "Referer" => "https://news.example.com/article?private=yes"
      }
    end

    serialized_arguments = enqueued_jobs.last.fetch(:args).to_s
    assert_not_includes serialized_arguments, "127.0.0.1"
    assert_not_includes serialized_arguments, user_agent
    assert_not_includes serialized_arguments, "private=yes"
  end

  test "does not enqueue for disabled DNT GPC or bot traffic" do
    link = links(:alice_docs)
    host! "localhost"

    assert_no_enqueued_jobs(only: RecordVisitJob) { get short_link_path(link.slug) }

    link.update!(tracking_enabled: true)
    assert_no_enqueued_jobs(only: RecordVisitJob) { get short_link_path(link.slug), headers: { "DNT" => "1" } }
    assert_no_enqueued_jobs(only: RecordVisitJob) { get short_link_path(link.slug), headers: { "Sec-GPC" => "1" } }
    assert_no_enqueued_jobs(only: RecordVisitJob) { get short_link_path(link.slug), headers: { "User-Agent" => BOT_USER_AGENT } }
  end
end
