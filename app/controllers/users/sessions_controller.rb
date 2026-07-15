module Users
  class SessionsController < Devise::SessionsController
    rate_limit to: 10,
      within: 5.minutes,
      by: -> { Privacy::RateLimitKey.call(request.remote_ip) },
      only: :create
  end
end
