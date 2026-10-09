# Rails mail subscribers log complete bodies and provider error messages.
# Keep only the redacted delivery outcome logged by AuthenticationDelivery.
Rails.application.config.action_mailer.logger = nil

Resend.api_key = ENV["RESEND_API_KEY"]

Rails.application.config.x.authentication_email_from = ENV.fetch("AUTH_EMAIL_FROM", "Visitly <hello@example.test>")
Rails.application.config.x.authentication_email_origin = ENV.fetch("APP_ORIGIN", "http://localhost:3000")

if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
  origin = URI.parse(ENV.fetch("APP_ORIGIN"))
  unless origin.scheme == "https" && origin.host.present? && origin.userinfo.nil? && origin.query.nil? && origin.fragment.nil? && [ "", "/" ].include?(origin.path)
    raise "APP_ORIGIN must be an HTTPS origin without credentials, path or query"
  end
  raise "RESEND_API_KEY is required" if ENV["RESEND_API_KEY"].blank?
  raise "AUTH_EMAIL_FROM is required" if ENV["AUTH_EMAIL_FROM"].blank?
end
