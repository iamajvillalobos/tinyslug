class CustomDomainsController < ApplicationController
  RATE_LIMIT_STORE = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

  before_action :authenticate_user!
  before_action :set_custom_domain, only: %i[show edit update destroy verify]

  rate_limit to: 5,
    within: 10.minutes,
    by: -> { Privacy::RateLimitKey.call("#{current_user.account.key}:#{request.remote_ip}") },
    store: RATE_LIMIT_STORE,
    only: :verify

  def index
    @custom_domains = current_user.account.custom_domains.order(:hostname)
  end

  def show
  end

  def new
    @custom_domain = current_user.account.custom_domains.new
  end

  def create
    @custom_domain = current_user.account.custom_domains.new(create_params)

    if @custom_domain.save
      redirect_to @custom_domain, notice: "Custom domain added. Configure its DNS records next."
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    @custom_domain.errors.add(:hostname, "has already been taken")
    render :new, status: :unprocessable_content
  end

  def edit
  end

  def update
    if @custom_domain.update(update_params)
      redirect_to @custom_domain, notice: "Fallback settings saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def verify
    result = CustomDomains::Verify.call(custom_domain: @custom_domain)
    if result.verified?
      redirect_to @custom_domain, notice: "Domain ownership and routing verified."
    else
      redirect_to @custom_domain, alert: result.errors.to_sentence
    end
  end

  def destroy
    result = CustomDomains::Destroy.call(custom_domain: @custom_domain, account: current_user.account)
    message = "Custom domain removed."
    if result.renamed_links.any?
      message += " #{result.renamed_links.size} conflicting link #{'slug'.pluralize(result.renamed_links.size)} renamed."
    end
    redirect_to custom_domains_path, notice: message, status: :see_other
  end

  private

  def set_custom_domain
    @custom_domain = current_user.account.custom_domains.find(params[:id])
  end

  def create_params
    params.expect(custom_domain: [ :hostname, :fallback_url ])
  end

  def update_params
    params.expect(custom_domain: [ :fallback_url ])
  end
end
