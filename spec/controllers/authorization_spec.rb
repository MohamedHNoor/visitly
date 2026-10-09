require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    before_action :require_membership
    before_action :require_owner
    def index
      head :ok
    end
  end

  %w[owner scheduler staff].each do |role|
    it "#{role == 'owner' ? 'allows' : 'denies'} #{role} access to owner actions" do
      user = User.create!(email_address: "#{role}@example.nz", display_name: role, password: "secure-pass-1", email_verified_at: Time.current)
      business = Business.create!(name: "Business", slug: role, industry: "cleaning", timezone: "Pacific/Auckland", trial_started_at: Time.current)
      Membership.create!(user: user, business: business, role: role)
      cookies.signed[:session_id] = user.sessions.create!.id
      get :index
      expect(response).to have_http_status(role == "owner" ? :ok : :forbidden)
    end
  end
end
