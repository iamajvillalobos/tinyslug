require "test_helper"

class CustomDomainsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:alice)
    CustomDomainsController::RATE_LIMIT_STORE.clear
  end

  test "lists only the current account's domains" do
    get custom_domains_path

    assert_response :success
    assert_includes response.body, custom_domains(:alice_verified).hostname
    assert_not_includes response.body, custom_domains(:bob_verified).hostname
  end

  test "creates a pending domain and displays DNS instructions" do
    assert_difference("accounts(:alice).custom_domains.count", 1) do
      post custom_domains_path, params: {
        custom_domain: { hostname: "go.new-example.test", fallback_url: "https://example.com" }
      }
    end

    domain = accounts(:alice).custom_domains.order(:created_at).last
    assert domain.pending?
    assert_redirected_to custom_domain_path(domain)

    get custom_domain_path(domain)
    assert_response :success
    assert_includes response.body, domain.txt_record_name
    assert_includes response.body, domain.verification_token
  end

  test "renders invalid hostnames and fallback URLs" do
    post custom_domains_path, params: {
      custom_domain: { hostname: "https://bad.example.com", fallback_url: "javascript:alert(1)" }
    }

    assert_response :unprocessable_content
    assert_select "[role=alert]"
  end

  test "updates a fallback without allowing hostname changes" do
    domain = custom_domains(:alice_pending)

    patch custom_domain_path(domain), params: {
      custom_domain: { hostname: "changed.example.test", fallback_url: "https://example.com/fallback" }
    }

    assert_redirected_to custom_domain_path(domain)
    assert_equal "https://example.com/fallback", domain.reload.fallback_url
    assert_equal "pending.alice.test", domain.hostname
  end

  test "deletes a domain while retaining its links" do
    domain = custom_domains(:alice_verified)
    link = links(:alice_custom)

    delete custom_domain_path(domain)

    assert_redirected_to custom_domains_path
    assert_not CustomDomain.exists?(domain.id)
    assert Link.exists?(link.id)
    assert_nil link.reload.custom_domain_id
  end

  test "cross-account requests return not found" do
    domain = custom_domains(:bob_verified)

    get custom_domain_path(domain)
    assert_response :not_found
    sign_in users(:alice)
    get edit_custom_domain_path(domain)
    assert_response :not_found
    sign_in users(:alice)
    patch custom_domain_path(domain), params: { custom_domain: { fallback_url: "https://example.com" } }
    assert_response :not_found
    sign_in users(:alice)
    post verify_custom_domain_path(domain)
    assert_response :not_found
    sign_in users(:alice)
    delete custom_domain_path(domain)
    assert_response :not_found
    assert CustomDomain.exists?(domain.id)
  end
end
