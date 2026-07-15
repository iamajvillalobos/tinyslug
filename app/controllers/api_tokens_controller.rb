class ApiTokensController < ApplicationController
  before_action :authenticate_user!

  rate_limit to: 10,
    within: 1.hour,
    by: -> { Privacy::RateLimitKey.call("#{current_user.account.key}:#{request.remote_ip}") },
    only: :create

  def index
    load_tokens
    @api_token = current_user.account.api_tokens.new
  end

  def create
    result = ApiToken.issue(account: current_user.account, name: api_token_params[:name])
    @api_token = result.api_token
    @plain_text_token = result.secret
    load_tokens

    if @api_token.persisted?
      @api_token = current_user.account.api_tokens.new
      render :index, status: :created
    else
      render :index, status: :unprocessable_content
    end
  end

  def revoke
    api_token = current_user.account.api_tokens.find(params[:id])
    api_token.revoke!
    redirect_to api_tokens_path, notice: "API token revoked.", status: :see_other
  end

  private

  def load_tokens
    @api_tokens = current_user.account.api_tokens.order(created_at: :desc)
  end

  def api_token_params
    params.expect(api_token: [ :name ])
  end
end
