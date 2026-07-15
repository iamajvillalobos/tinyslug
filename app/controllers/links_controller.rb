class LinksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_link, only: %i[show edit update destroy qr export]
  before_action :load_form_collections, only: %i[index new create edit update]

  def index
    @pagy, @links = search_results
    @link = current_user.account.links.new(source: :dashboard)
  end

  def show
  end

  def new
    @link = current_user.account.links.new(source: :dashboard)
  end

  def create
    result = Links::Create.call(account: current_user.account, attributes: link_params, source: :dashboard)
    @link = result.link
    @created = result.created?

    if result.created? || result.reused?
      message = result.created? ? "Short link created." : "Matching short link already exists."
      respond_to do |format|
        format.html { redirect_to @link, notice: message }
        format.turbo_stream { flash.now.notice = message }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }
        format.turbo_stream { render :create, status: :unprocessable_content }
      end
    end
  end

  def edit
  end

  def update
    @link = Links::Update.call(link: @link, account: current_user.account, attributes: link_params)

    if @link.errors.empty?
      respond_to do |format|
        format.html { redirect_to @link, notice: "Link updated." }
        format.turbo_stream { flash.now.notice = "Link updated." }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_content }
        format.turbo_stream { render :update, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @link.destroy!

    respond_to do |format|
      format.html { redirect_to links_path, notice: "Link deleted.", status: :see_other }
      format.turbo_stream { flash.now.notice = "Link deleted." }
    end
  end

  def qr
    qr_code = RQRCode::QRCode.new(@link.short_url)

    respond_to do |format|
      format.svg do
        send_data qr_code.as_svg(module_size: 6), filename: "#{@link.slug}.svg", type: "image/svg+xml", disposition: :attachment
      end
      format.png do
        send_data qr_code.as_png(size: 720).to_s, filename: "#{@link.slug}.png", type: "image/png", disposition: :attachment
      end
    end
  end

  def export
    send_data Links::CsvExport.call([ @link ]),
      filename: "#{@link.slug}.csv",
      type: "text/csv; charset=utf-8",
      disposition: :attachment
  end

  def export_all
    links = current_user.account.links.includes(:custom_domain, :tags).order(created_at: :desc)
    send_data Links::CsvExport.call(links),
      filename: "tinyslug-links-#{Date.current.iso8601}.csv",
      type: "text/csv; charset=utf-8",
      disposition: :attachment
  end

  private

  def set_link
    @link = current_user.account.links.find(params[:id])
  end

  def load_form_collections
    @tags = current_user.account.tags.order(:name)
    @custom_domains = current_user.account.custom_domains.verified.order(:hostname)
  end

  def link_params
    params.expect(link: [ :destination_url, :name, :slug, :custom_domain_id, :tracking_enabled, :tags ])
  end

  def search_results
    Links::Search.call(
      account: current_user.account,
      query: params[:query],
      tag: params[:tag],
      sort: params[:sort],
      page: params[:page]
    )
  end
end
