Rails.application.config.action_dispatch.default_headers.merge!(
  "Permissions-Policy" => "camera=(), geolocation=(), microphone=(), payment=(), usb=()",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "X-Content-Type-Options" => "nosniff",
  "X-Frame-Options" => "DENY"
)
