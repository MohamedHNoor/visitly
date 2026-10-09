require "rails_helper"

RSpec.describe "Owner onboarding", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { User.create!(email_address: "owner@example.nz", display_name: "Owner", password: "secure-pass-1", email_verified_at: Time.current) }
  let(:details) { { name: "Fresh Home", industry: "cleaning", timezone: "Pacific/Chatham" } }

  def sign_in
    post session_path, params: { email_address: user.email_address, password: "secure-pass-1" }
  end

  it "directs verified users without membership into onboarding" do
    sign_in
    expect(response).to redirect_to(new_onboarding_path)
    get new_onboarding_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Business name", "Pacific/Chatham")
  end

  it "requires authentication" do
    post onboarding_path, params: { business: details }
    expect(response).to redirect_to(new_session_path)
    expect(Business.count).to eq(0)
  end

  it "requires verification" do
    user.update!(email_verified_at: nil)
    sign_in
    post onboarding_path, params: { business: details }
    expect(response).to redirect_to(verification_pending_path)
    expect(Business.count).to eq(0)
  end

  it "creates an owner membership and starts the trial at creation" do
    sign_in
    freeze_time do
      post onboarding_path, params: { business: details.merge(currency: "USD", role: "staff", trial_started_at: 1.year.ago, slug: "forged") }
      expect(response).to redirect_to(setup_complete_path)
      business = user.reload.membership.business
      expect(business.trial_started_at).to eq(Time.current)
      expect(business.currency).to eq("NZD")
      expect(business.timezone).to eq("Pacific/Chatham")
      expect(business.slug).to match(/\Afresh-home-[a-f0-9]{12}\z/)
      expect(user.membership.role).to eq("owner")
    end
    get setup_complete_path
    expect(response.body).to include("Your workspace is ready.", "Fresh Home", "Open workspace")
    expect(response.body).not_to include('href="/services"', 'href="/staff"')
  end

  it "does not create another workspace on repeated submission" do
    sign_in
    post onboarding_path, params: { business: details }
    first = user.reload.membership.business
    post onboarding_path, params: { business: details.merge(name: "Another") }
    expect(response).to redirect_to(workspace_path)
    expect(Business.count).to eq(1)
    expect(user.create_workspace!(details)).to eq(first)
    expect(Business.count).to eq(1)
  end

  it "preserves submitted values and associated errors for invalid details" do
    sign_in
    post onboarding_path, params: { business: details.merge(name: "", industry: "salon") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('id="name-error"', 'aria-describedby="name-error"')
    expect(Nokogiri::HTML(response.body).at_css("select[name='business[timezone]'] option[selected]")["value"]).to eq("Pacific/Chatham")
    expect(Business.count).to eq(0)
    expect(Membership.count).to eq(0)
  end

  it "rolls back the business if membership persistence fails" do
    allow(Membership).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, "simulated database failure")
    expect { user.create_workspace!(details) }.to raise_error(ActiveRecord::StatementInvalid)
    expect(Business.count).to eq(0)
    expect(Membership.count).to eq(0)
  end

  it "rejects unverified creation at the model boundary too" do
    user.update!(email_verified_at: nil)
    expect { user.create_workspace!(details) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Business.count).to eq(0)
  end

  it "denies non-owners access to setup completion and additional onboarding" do
    business = Business.create!(details.merge(slug: "existing", trial_started_at: Time.current))
    Membership.create!(user: user, business: business, role: "staff")
    sign_in
    get setup_complete_path
    expect(response).to have_http_status(:forbidden)
    post onboarding_path, params: { business: details }
    expect(response).to redirect_to(workspace_path)
    expect(Business.count).to eq(1)
  end

  it "has a deterministic test seam for slug generation" do
    allow(SecureRandom).to receive(:hex).with(6).and_return("abc123abc123")
    expect(Business.generate_slug("Fresh Home")).to eq("fresh-home-abc123abc123")
    expect(Business.generate_slug("✨")).to eq("business-abc123abc123")
  end
end
