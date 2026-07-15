class RedirectsController < ApplicationController
  def show
    outcome = Links::Resolve.call(
      host: request.host_with_port,
      slug: params[:slug],
      primary_host: Rails.configuration.x.app_host
    )

    if outcome.found?
      capture_visit(outcome.link)
      redirect_to outcome.link.destination_url, allow_other_host: true, status: :found
    elsif outcome.fallback?
      redirect_to outcome.fallback_url, allow_other_host: true, status: :found
    else
      head :not_found
    end
  end

  private

  def capture_visit(link)
    payload = Visits::PayloadBuilder.call(
      link:,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      referrer: request.referrer,
      dnt: request.headers["DNT"],
      gpc: request.headers["Sec-GPC"],
      country_code: trusted_country_code
    )
    RecordVisitJob.perform_later(payload) if payload
  end

  def trusted_country_code
    header = ENV["TRUSTED_COUNTRY_HEADER"]
    request.headers[header] if header.present?
  end
end
