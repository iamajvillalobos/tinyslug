class RedirectsController < ApplicationController
  def show
    outcome = Links::Resolve.call(
      host: request.host_with_port,
      slug: params[:slug],
      primary_host: Rails.configuration.x.app_host
    )

    if outcome.found?
      redirect_to outcome.link.destination_url, allow_other_host: true, status: :found
    elsif outcome.fallback?
      redirect_to outcome.fallback_url, allow_other_host: true, status: :found
    else
      head :not_found
    end
  end
end
