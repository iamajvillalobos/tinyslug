module Users
  class PasswordsController < Devise::PasswordsController
    rate_limit to: 5,
      within: 15.minutes,
      by: -> { Privacy::RateLimitKey.call(request.remote_ip) },
      only: :create
  end
end
