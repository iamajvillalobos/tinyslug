require "test_helper"

module Api
  module V1
    class LinksControllerTest < ActionDispatch::IntegrationTest
      setup do
        Api::V1::LinksController::RATE_LIMIT_STORE.clear
        @issued_token = ApiToken.issue(account: accounts(:alice), name: "API test")
      end

      teardown do
        Api::V1::LinksController::RATE_LIMIT_STORE.clear
      end

      test "rejects missing malformed unknown and revoked tokens" do
        post api_v1_links_path, params: valid_payload, as: :json
        assert_response :unauthorized

        post api_v1_links_path, params: valid_payload, headers: { "Authorization" => "Basic nope" }, as: :json
        assert_response :unauthorized

        post api_v1_links_path, params: valid_payload, headers: bearer("ts_unknown"), as: :json
        assert_response :unauthorized

        @issued_token.api_token.revoke!
        post api_v1_links_path, params: valid_payload, headers: bearer(@issued_token.secret), as: :json
        assert_response :unauthorized
      end

      test "creates a link with the documented JSON contract" do
        assert_difference("accounts(:alice).links.count", 1) do
          post api_v1_links_path,
            params: {
              link: {
                destination_url: "https://example.com/api-article",
                name: "API article",
                slug: "api-article",
                tracking_enabled: true,
                tags: [ "docs", "example" ]
              }
            },
            headers: bearer(@issued_token.secret),
            as: :json
        end

        assert_response :created
        representation = response.parsed_body.fetch("link")
        assert_equal %w[created_at destination_url id name short_url slug tags tracking_enabled], representation.keys.sort
        assert_equal "api-article", representation.fetch("slug")
        assert_equal %w[docs example], representation.fetch("tags")
        assert accounts(:alice).links.order(:created_at).last.api?
        assert_not_includes response.body, "account_id"
        assert_not_includes response.body, "token_digest"
        assert_not_includes response.body, "verification_token"
      end

      test "returns OK when the shared operation reuses an unnamed link" do
        payload = { link: { destination_url: links(:alice_docs).destination_url } }

        assert_no_difference("Link.count") do
          post api_v1_links_path, params: payload, headers: bearer(@issued_token.secret), as: :json
        end

        assert_response :ok
        assert_equal links(:alice_docs).id, response.parsed_body.dig("link", "id")
      end

      test "returns validation errors without leaking another account's domain" do
        post api_v1_links_path,
          params: {
            link: {
              destination_url: "javascript:alert(1)",
              custom_domain_id: custom_domains(:bob_verified).id
            }
          },
          headers: bearer(@issued_token.secret),
          as: :json

        assert_response :unprocessable_content
        assert response.parsed_body.fetch("errors").key?("custom_domain")
        assert_not_includes response.body, custom_domains(:bob_verified).hostname
      end

      test "requires a link object" do
        post api_v1_links_path, params: {}, headers: bearer(@issued_token.secret), as: :json

        assert_response :unprocessable_content
        assert_equal [ "is required" ], response.parsed_body.dig("errors", "link")
      end

      private

      def bearer(secret)
        { "Authorization" => "Bearer #{secret}" }
      end

      def valid_payload
        { link: { destination_url: "https://example.com/api" } }
      end
    end
  end
end
