# Authentication email setup

Production uses the Resend HTTPS Action Mailer adapter, supported on Railway plans where SMTP is blocked. Set these server environment variables using the hosting secret manager:

- `RESEND_API_KEY`: a Resend sending key scoped to the verified sender domain.
- `AUTH_EMAIL_FROM`: a real sender address on that domain, optionally `Visitly <hello@mail.your-domain>`.
- `APP_ORIGIN`: the canonical HTTPS application origin, with no path, query or credentials.

Production web boot rejects missing settings; asset precompilation with `SECRET_KEY_BASE_DUMMY=1` does not require secrets. Production enables HTTPS redirects and secure cookies. Configure your proxy correctly before launch. Never commit keys or use incoming request hosts to build email links.

Verify the sending domain in Resend and publish its required DKIM/SPF records; configure DMARC according to the domain's approved policy. Use a monitored sender inbox. Domain/DNS changes and real sending are operator actions, not performed by this feature.

Development uses file delivery: actual emails are written to `tmp/mails/`, with no external sends. After registering or resending, open the file named after the recipient address and use its verification link. Files contain sensitive tokens, are ignored by Git under `tmp/`, and should stay local. Restart the development server after changing delivery configuration. Visit `/rails/mailers/authentication_mailer` for fixture previews. RSpec also uses test delivery. Previews do not create users or usable tokens.

Verification and invitation delivery is synchronous with a 10-second boundary; expected provider/network failures show safe retry guidance. Password recovery enqueues `PasswordResetDeliveryJob` for every request, so the response is identical in content and timing whether or not the account exists; the job looks up the account and delivers with the same boundary. In production this needs the Solid Queue worker (`bin/jobs`) running. Unexpected programming errors propagate. Rails mail body/error logging is disabled; only redacted delivery outcomes are logged. No provider error body, token or key is logged. Resending rotates the link. Provider acceptance does not prove inbox delivery. Feature 7 adds the durable outbox/recovery before pilot launch.

References: https://resend.com/rails and https://docs.railway.com/networking/outbound-networking.
