require "rails_helper"

RSpec.describe "Workspace invitations", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:business) { Business.create!(name: "Clean Team", slug: "clean-team", industry: "cleaning", timezone: "Pacific/Auckland", trial_started_at: Time.current) }
  let(:owner) { account("owner@example.nz") }
  let(:invitee) { account("staff@example.nz") }
  let(:owner_membership) { Membership.create!(user: owner, business: business, role: "owner") }
  let(:token) { "a-random-test-token" }
  let(:invitation) { Invitation.create!(business: business, inviting_membership: owner_membership, email_address: invitee.email_address, role: "staff", token_digest: Invitation.digest(token), expires_at: 7.days.from_now) }

  def account(email)
    User.create!(email_address: email, display_name: "Alex", password: "secure-pass-1", email_verified_at: Time.current)
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "secure-pass-1" }
  end

  it "lets Owners send invitations with trusted business and inviter" do
    owner_membership
    sign_in(owner)
    post invitations_path, params: { invitation: { email_address: " STAFF@EXAMPLE.NZ ", role: "scheduler", business_id: "forged", inviting_membership_id: "forged" } }
    record = Invitation.last
    expect(response).to redirect_to(invitations_path)
    expect(record.business).to eq(business)
    expect(record.inviting_membership).to eq(owner_membership)
    expect(record.email_address).to eq("staff@example.nz")
    expect(record.role).to eq("scheduler")
    expect(record.token_digest).to match(/\A[a-f0-9]{64}\z/)
    expect(ActionMailer::Base.deliveries.last.subject).to eq("Your Visitly workspace invitation")
  end

  %w[scheduler staff].each do |role|
    it "denies #{role} invitation management" do
      Membership.create!(user: invitee, business: business, role: role)
      sign_in(invitee)
      post invitations_path, params: { invitation: { email_address: "other@example.nz", role: "staff" } }
      expect(response).to have_http_status(:forbidden)
      expect(Invitation.count).to eq(0)
    end
  end

  it "rejects Owner role invitations with feedback" do
    owner_membership
    sign_in(owner)
    post invitations_path, params: { invitation: { email_address: invitee.email_address, role: "owner" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('id="role-error"')
    expect(Invitation.count).to eq(0)
  end

  it "scopes revocation and resend to the Owner workspace" do
    invitation
    other = Business.create!(name: "Other", slug: "other", industry: "cleaning", timezone: "Pacific/Auckland", trial_started_at: Time.current)
    outsider = account("other-owner@example.nz")
    Membership.create!(user: outsider, business: other, role: "owner")
    sign_in(outsider)
    delete invitation_path(invitation)
    expect(response).to have_http_status(:not_found)
    post resend_invitation_path(invitation)
    expect(response).to have_http_status(:not_found)
    expect(invitation.reload.revoked_at).to be_nil
    expect(invitation.token_digest).to eq(Invitation.digest(token))
  end

  it "renders invalid invitations and a useful unsigned acceptance path" do
    get invitation_acceptance_path, params: { token: "unknown" }
    expect(response).to redirect_to(invitation_acceptance_path)
    follow_redirect!
    expect(response.body).to include("invalid, expired, revoked")
    invitation
    get invitation_acceptance_path, params: { token: token }
    follow_redirect!
    expect(response.body).to include("Clean Team", 'href="/login"', 'href="/register"', "come back to this invitation after signing in")
    expect(Membership.count).to eq(1)
  end

  it "atomically accepts for the matching verified user and rejects repeat acceptance" do
    invitation
    sign_in(invitee)
    post invitation_acceptance_path, params: { token: token, role: "owner", business_id: "forged" }
    expect(response).to redirect_to(workspace_path)
    expect(invitee.reload.membership.role).to eq("staff")
    expect(invitee.membership.business).to eq(business)
    expect(invitation.reload.accepted_at).to be_present
    post invitation_acceptance_path, params: { token: token }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Membership.where(user: invitee).count).to eq(1)
  end

  it "denies wrong email and unverified users" do
    invitation
    wrong = account("wrong@example.nz")
    sign_in(wrong)
    post invitation_acceptance_path, params: { token: token }
    expect(response).to have_http_status(:unprocessable_content)
    invitee.update!(email_verified_at: nil)
    sign_in(invitee)
    post invitation_acceptance_path, params: { token: token }
    expect(response).to have_http_status(:unprocessable_content)
    expect(invitation.reload.accepted_at).to be_nil
  end

  it "denies acceptance for a user already in any workspace" do
    invitation
    Membership.create!(user: invitee, business: business, role: "scheduler")
    sign_in(invitee)
    post invitation_acceptance_path, params: { token: token }
    expect(response).to have_http_status(:unprocessable_content)
    expect(invitation.reload.accepted_at).to be_nil
  end

  it "rejects expired and revoked invitations" do
    invitation
    sign_in(invitee)
    travel 7.days + 1.second do
      post invitation_acceptance_path, params: { token: token }
      expect(response).to have_http_status(:unprocessable_content)
    end
    invitation.revoke!
    post invitation_acceptance_path, params: { token: token }
    expect(response).to have_http_status(:unprocessable_content)
    expect(invitee.reload.membership).to be_nil
  end

  it "invalidates the previous token on resend and renews expiry" do
    invitation
    sign_in(owner)
    travel 8.days do
      post resend_invitation_path(invitation)
      expect(invitation.reload.expires_at).to be_within(1.second).of(7.days.from_now)
      expect(invitation.token_digest).not_to eq(Invitation.digest(token))
    end
    get invitation_acceptance_path, params: { token: token }
    follow_redirect!
    expect(response.body).to include("invalid, expired, revoked")
  end

  it "does not revive revoked invitations" do
    invitation.revoke!
    sign_in(owner)
    post resend_invitation_path(invitation)
    expect(invitation.reload.revoked_at).to be_present
    expect(invitation.token_digest).to eq(Invitation.digest(token))
  end

  it "rolls membership back when invitation consumption fails" do
    invitation
    allow(invitation).to receive(:update!).and_raise(ActiveRecord::StatementInvalid, "simulated failure")
    expect { invitation.accept!(invitee, token) }.to raise_error(ActiveRecord::StatementInvalid)
    expect(invitee.reload.membership).to be_nil
    expect(invitation.reload.accepted_at).to be_nil
  end

  it "keeps failed delivery recoverable without revealing the provider message" do
    owner_membership
    sign_in(owner)
    allow(AuthenticationMailer).to receive(:invitation).and_raise(Resend::Error.new("private provider details", 503))
    post invitations_path, params: { invitation: { email_address: invitee.email_address, role: "staff" } }
    follow_redirect!
    expect(response.body).to include("email is unavailable", "Resend")
    expect(response.body).not_to include("private provider details")
    expect(Invitation.count).to eq(1)
  end
  it "limits acceptance attempts without consuming an invitation" do
    invitation
    sign_in(invitee)
    store = ActiveSupport::Cache::MemoryStore.new
    allow_any_instance_of(InvitationAcceptancesController).to receive(:rate_limiting).and_wrap_original do |method, **options|
      method.call(**options.merge(store: store))
    end
    10.times { post invitation_acceptance_path, params: { token: "invalid" } }
    post invitation_acceptance_path, params: { token: token }
    expect(response).to have_http_status(:too_many_requests)
    expect(invitation.reload.accepted_at).to be_nil
    expect(invitee.reload.membership).to be_nil
  end

  describe "signed-in invitation page" do
    def open_invitation
      get invitation_acceptance_path, params: { token: token }
      follow_redirect!
    end

    it "offers acceptance only to the matching verified user without a workspace" do
      invitation
      sign_in(invitee)
      open_invitation
      expect(response.body).to include("Accept invitation")
    end

    it "explains a different email instead of offering acceptance" do
      invitation
      other = account("someone-else@example.nz")
      sign_in(other)
      open_invitation
      expect(response.body).to include("sent to a different email address")
      expect(response.body).not_to include("Accept invitation")
    end

    it "explains an existing workspace membership" do
      invitation
      Membership.create!(user: invitee, business: Business.create!(name: "Other", slug: "other", industry: "detailing", timezone: "Pacific/Auckland", trial_started_at: Time.current), role: "owner")
      sign_in(invitee)
      open_invitation
      expect(response.body).to include("already belongs to a workspace")
      expect(response.body).not_to include("Accept invitation")
    end

    it "asks an unverified invitee to verify first" do
      invitation
      invitee.update!(email_verified_at: nil)
      sign_in(invitee)
      open_invitation
      expect(response.body).to include("Verify your email address before accepting")
      expect(response.body).not_to include("Accept invitation")
    end
  end

  describe "returning to an invitation after sign-in" do
    it "brings a verified invitee without a workspace back to the invitation" do
      invitation
      get invitation_acceptance_path, params: { token: token }
      sign_in(invitee)
      expect(response).to redirect_to(invitation_acceptance_path)
      follow_redirect!
      expect(response.body).to include("Clean Team", "Accept invitation")
      post invitation_acceptance_path, params: { token: token }
      expect(response).to redirect_to(workspace_path)
      expect(invitee.reload.membership.role).to eq("staff")
    end

    it "sends members to their workspace and others to onboarding as before" do
      invitation
      owner_membership
      get invitation_acceptance_path, params: { token: token }
      sign_in(owner)
      expect(response).to redirect_to(workspace_path)
      delete session_path
      sign_in(invitee)
      expect(response).to redirect_to(new_onboarding_path)
    end
  end
end
