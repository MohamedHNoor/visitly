require "rails_helper"

RSpec.describe "Registration and recovery", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper
  let(:user) { User.create!(email_address: "alex@example.nz", display_name: "Alex", password: "original-pass-1") }

  before { ActionMailer::Base.deliveries.clear }

  def register(attributes = {})
    post registration_path, params: { user: { display_name: "Alex", email_address: "Alex@Example.nz", password: "original-pass-1", password_confirmation: "original-pass-1" }.merge(attributes) }
  end

  it "registers an unverified account and sends a verification email" do
    register
    expect(response).to redirect_to(verification_pending_path)
    account = User.find_by!(email_address: "alex@example.nz")
    expect(account.email_verified_at).to be_nil
    expect(account.membership).to be_nil
    expect(ActionMailer::Base.deliveries.last.subject).to eq("Verify your email for Visitly")
    get verification_pending_path
    expect(response.body).to include("Check your email", "<title>Check your email · Visitly</title>")
  end

  it "requires 8+ character passwords with a number and a special character, with an accessible hint" do
    get new_registration_path
    expect(response.body).to include('minlength="8"', 'id="password-hint"', "including a number and a special character")
    { "ab-1cd" => "is too short (minimum is 8 characters)",
      "abcdefg-h" => "must include a number",
      "abcdefg12" => "must include a special character" }.each do |password, message|
      register(password: password, password_confirmation: password)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(message, 'aria-describedby="password-hint password-error"')
    end
    expect(User.exists?(email_address: "alex@example.nz")).to be(false)
    register(password: "abcdef1!", password_confirmation: "abcdef1!")
    expect(response).to redirect_to(verification_pending_path)
  end

  it "renders a progressive show-password toggle tied to each password field" do
    get new_registration_path
    expect(response.body).to include('aria-controls="user_password"', 'aria-controls="user_password_confirmation"')
    expect(response.body.scan(/<button type="button" class="password-toggle" hidden aria-label="Show password" aria-pressed="false"/).size).to eq(2)
    get new_session_path
    expect(response.body).to include('aria-controls="password"', 'data-password-visibility-target="input"')
  end

  it "rejects a short replacement password without consuming the reset link" do
    token = user.issue_reset_token!
    patch password_path, params: { token: token, user: { password: "abc-1", password_confirmation: "abc-1" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("is too short (minimum is 8 characters)")
    expect(user.reload.authenticate("original-pass-1")).to eq(user)
    expect(User.find_by_token_for(:password_recovery, token)).to eq(user)
  end

  it "preserves non-secret input with associated validation feedback" do
    register(password_confirmation: "different")
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('id="password_confirmation-error"', 'aria-describedby="password_confirmation-error"', 'value="Alex"')
    expect(response.body).not_to include('value="original-pass-1"')
    expect(User.count).to eq(0)
  end

  it "does not save verification, membership or role fields supplied by the client" do
    register(email_verified_at: Time.current, role: "owner")
    expect(User.last.email_verified_at).to be_nil
    expect(Membership.count).to eq(0)
  end

  it "saves a recoverable account on an expected delivery failure" do
    allow(AuthenticationMailer).to receive(:verification).and_raise(Resend::Error.new("secret provider message", 503))
    register
    get verification_pending_path
    expect(response.body).to include("email is unavailable")
    expect(response.body).not_to include("secret provider message")
    expect(User.count).to eq(1)
  end

  it "lets unexpected delivery programming errors propagate" do
    allow(AuthenticationMailer).to receive(:verification).and_raise(NoMethodError, "programming error")
    expect { register }.to raise_error(NoMethodError)
  end

  it "only verifies on a mutation and rejects replay" do
    token = user.issue_verification_token!
    get verification_path, params: { token: token }
    expect(response).to redirect_to(verification_path)
    follow_redirect!
    expect(response.body).to include("Verify email", "<title>Verify your email · Visitly</title>")
    expect(user.reload.email_verified_at).to be_nil
    patch verification_path, params: { token: token }
    expect(user.reload.email_verified_at).to be_present
    patch verification_path, params: { token: token }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rotates verification links on resend" do
    old = user.issue_verification_token!
    post session_path, params: { email_address: user.email_address, password: "original-pass-1" }
    post verification_path
    patch verification_path, params: { token: old }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.email_verified_at).to be_nil
    expect(ActionMailer::Base.deliveries.count).to eq(1)
  end

  it "expires verification links after 24 hours" do
    token = user.issue_verification_token!
    travel 24.hours + 1.second do
      patch verification_path, params: { token: token }
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(user.reload.email_verified_at).to be_nil
  end

  it "does the same request-time work for known and unknown accounts" do
    user
    expect { post passwords_path, params: { email_address: "unknown@example.nz" } }
      .to have_enqueued_job(PasswordResetDeliveryJob).with("unknown@example.nz")
    unknown = response.body
    nonce = user.reload.reset_nonce
    expect { post passwords_path, params: { email_address: " Alex@Example.nz " } }
      .to have_enqueued_job(PasswordResetDeliveryJob).with("alex@example.nz")
    expect(response).to have_http_status(:ok)
    expect(response.body.sub('value=" Alex@Example.nz "', 'value="unknown@example.nz"')).to eq(unknown)
    expect(user.reload.reset_nonce).to eq(nonce)
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "sends reset email from the job only for existing accounts" do
    PasswordResetDeliveryJob.perform_now("unknown@example.nz")
    expect(ActionMailer::Base.deliveries).to be_empty
    PasswordResetDeliveryJob.perform_now(user.email_address)
    expect(ActionMailer::Base.deliveries.last.subject).to eq("Reset your password for Visitly")
    expect(PasswordResetDeliveryJob.log_arguments?).to be(false)
  end

  it "contains expected provider failures in the reset job without leaking details" do
    allow(AuthenticationMailer).to receive(:password_reset).and_raise(Resend::Error.new("private details", 503))
    allow(Rails.logger).to receive(:warn)
    expect { PasswordResetDeliveryJob.perform_now(user.email_address) }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with("Authentication email unavailable: Resend::Error")
  end

  it "resets a password atomically and revokes all sessions" do
    first = user.sessions.create!
    user.sessions.create!
    token = user.issue_reset_token!
    get edit_password_path, params: { token: token }
    expect(response).to redirect_to(edit_password_path)
    follow_redirect!
    expect(response.body).to include("Reset password")
    expect(user.reload.authenticate("original-pass-1")).to eq(user)
    patch password_path, params: { token: token, user: { password: "updated-pass-2", password_confirmation: "updated-pass-2" } }
    expect(response).to redirect_to(new_session_path)
    expect(user.reload.authenticate("updated-pass-2")).to eq(user)
    expect(Session.exists?(first.id)).to be(false)
    expect(user.sessions.count).to eq(0)
    patch password_path, params: { token: token, user: { password: "hijacked-pass-3" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "preserves password and sessions on invalid replacement" do
    user.sessions.create!
    token = user.issue_reset_token!
    patch password_path, params: { token: token, user: { password: "updated-pass-2", password_confirmation: "mismatch" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.authenticate("original-pass-1")).to eq(user)
    expect(user.sessions.count).to eq(1)
    expect(User.find_by_token_for(:password_recovery, token)).to eq(user)
  end

  it "expires and rotates reset links and rejects purpose mixing" do
    old = user.issue_reset_token!
    current = user.issue_reset_token!
    expect(User.find_by_token_for(:password_recovery, old)).to be_nil
    expect(User.find_by_token_for(:email_verification, current)).to be_nil
    travel 15.minutes + 1.second do
      get edit_password_path, params: { token: current }
      follow_redirect!
      expect(response.body).to include("invalid, expired or already used")
    end
  end

  it "rejects tampered links" do
    patch verification_path, params: { token: user.issue_verification_token! + "x" }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "enforces CSRF on verification mutations" do
    old = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    patch verification_path, params: { token: user.issue_verification_token! }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.email_verified_at).to be_nil
  ensure
    ActionController::Base.allow_forgery_protection = old
  end

  it "limits reset requests without changing account state after the limit" do
    store = ActiveSupport::Cache::MemoryStore.new
    allow_any_instance_of(PasswordsController).to receive(:rate_limiting).and_wrap_original do |method, **options|
      method.call(**options.merge(store: store))
    end
    perform_enqueued_jobs { 3.times { post passwords_path, params: { email_address: user.email_address } } }
    token_version = user.reload.reset_nonce
    expect { post passwords_path, params: { email_address: user.email_address } }.not_to have_enqueued_job(PasswordResetDeliveryJob)
    expect(response).to have_http_status(:too_many_requests)
    expect(user.reload.reset_nonce).to eq(token_version)
    travel 10.minutes + 1.second do
      post passwords_path, params: { email_address: user.email_address }
      expect(response).to have_http_status(:ok)
    end
  end
  it "limits registration attempts" do
    store = ActiveSupport::Cache::MemoryStore.new
    allow_any_instance_of(RegistrationsController).to receive(:rate_limiting).and_wrap_original do |method, **options|
      method.call(**options.merge(store: store))
    end
    5.times { register(password_confirmation: "mismatch") }
    register
    expect(response).to have_http_status(:too_many_requests)
    expect(User.count).to eq(0)
  end

  it "limits verification resends without rotating a token after the limit" do
    store = ActiveSupport::Cache::MemoryStore.new
    allow_any_instance_of(VerificationsController).to receive(:rate_limiting).and_wrap_original do |method, **options|
      method.call(**options.merge(store: store))
    end
    post session_path, params: { email_address: user.email_address, password: "original-pass-1" }
    3.times { post verification_path }
    version = user.reload.verification_nonce
    post verification_path
    follow_redirect!
    expect(response.body).to include("Too many requests")
    expect(user.reload.verification_nonce).to eq(version)
  end

  it "does not expose the stored password hash in signed reset token contents" do
    token = user.issue_reset_token!
    contents = User.generated_token_verifier.verified(token, purpose: User.token_definitions[:password_recovery].full_purpose)
    expect(contents).to be_present
    expect(contents.to_json).not_to include(user.password_digest)
  end
end
