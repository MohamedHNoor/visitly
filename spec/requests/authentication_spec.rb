require "rails_helper"

RSpec.describe "Workspace authentication", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { User.create!(email_address: "owner@example.nz", display_name: "Alex", password: "secure-pass-1", email_verified_at: Time.current) }
  let(:business) { Business.create!(name: "Private Clean", slug: "private-clean", industry: "cleaning", timezone: "Pacific/Auckland", trial_started_at: Time.current) }

  def sign_in
    post session_path, params: { email_address: user.email_address, password: "secure-pass-1" }
  end

  it "redirects anonymous access to sign in" do
    get workspace_path
    expect(response).to redirect_to(new_session_path)
  end

  it "keeps marketing publicly accessible" do
    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "authenticates and scopes workspace access through membership" do
    Membership.create!(user: user, business: business, role: "owner")
    Business.create!(name: "Other Secret", slug: "other", industry: "detailing", timezone: "Pacific/Chatham", trial_started_at: Time.current)
    sign_in
    expect(response).to redirect_to(workspace_path)
    get workspace_path, params: { business_id: Business.find_by!(slug: "other").id }
    expect(response.body).to include("Private Clean")
    expect(response.body).not_to include("Other Secret")
  end

  it "denies users without membership" do
    sign_in
    get workspace_path
    expect(response).to have_http_status(:forbidden)
  end

  it "denies unverified members" do
    Membership.create!(user: user, business: business, role: "owner")
    user.update!(email_verified_at: nil)
    sign_in
    get workspace_path
    expect(response).to have_http_status(:forbidden)
  end

  it "limits Staff landing to their own identity and role" do
    Membership.create!(user: user, business: business, role: "staff")
    sign_in
    get workspace_path
    expect(response.body).to include("Alex", "Staff")
    expect(response.body).not_to include("Private Clean")
  end

  it "allows Scheduler membership access" do
    Membership.create!(user: user, business: business, role: "scheduler")
    sign_in
    get workspace_path
    expect(response).to have_http_status(:ok)
  end

  it "rejects a revoked session cookie" do
    sign_in
    user.sessions.destroy_all
    get workspace_path
    expect(response).to redirect_to(new_session_path)
  end

  it "revokes the current session on sign out" do
    sign_in
    delete session_path
    expect(user.sessions.count).to eq(0)
    get workspace_path
    expect(response).to redirect_to(new_session_path)
  end

  it "returns safe feedback for incorrect credentials" do
    post session_path, params: { email_address: user.email_address, password: "wrong" }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Email or password is incorrect.")
    expect(response.body).not_to include('value="wrong"')
    expect(user.sessions.count).to eq(0)
  end

  it "limits sign-in attempts per IP and recovers after the window" do
    store = ActiveSupport::Cache::MemoryStore.new
    allow_any_instance_of(SessionsController).to receive(:rate_limiting).and_wrap_original do |method, **options|
      method.call(**options.merge(store: store))
    end
    10.times { post session_path, params: { email_address: user.email_address, password: "wrong" } }
    sign_in
    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to include("Too many attempts. Please try again in a few minutes.")
    expect(user.sessions.count).to eq(0)
    travel 3.minutes + 1.second do
      sign_in
      expect(response).to redirect_to(new_onboarding_path)
      expect(user.sessions.count).to eq(1)
    end
  end
end
