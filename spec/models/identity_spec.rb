require "rails_helper"

RSpec.describe "Identity persistence", type: :model do
  def user(email = "owner@example.nz")
    User.create!(email_address: email, display_name: "Owner", password: "secure-pass-1", email_verified_at: Time.current)
  end

  def business(slug = "clean")
    Business.create!(name: "Clean", slug: slug, industry: "cleaning", timezone: "Pacific/Auckland", trial_started_at: Time.current)
  end

  it "normalizes email and authenticates passwords" do
    account = user(" OWNER@Example.NZ ")
    expect(account.email_address).to eq("owner@example.nz")
    expect(User.authenticate_by(email_address: " OWNER@example.nz ", password: "secure-pass-1")).to eq(account)
    expect(account.authenticate("incorrect")).to be(false)
  end

  it "enforces email uniqueness at the database boundary" do
    account = user
    duplicate = account.attributes.except("id")
    expect { User.insert_all!([ duplicate ]) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "requires display name and password" do
    expect(User.new(email_address: "new@example.nz")).not_to be_valid
  end

  it "enforces one membership per user in the database" do
    account = user
    membership = Membership.create!(user: account, business: business, role: "owner")
    second = membership.attributes.except("id").merge("business_id" => business("other").id)
    expect { Membership.insert_all!([ second ]) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects cross-business inviters in the database" do
    inviter = Membership.create!(user: user, business: business, role: "owner")
    values = { business_id: business("other").id, inviting_membership_id: inviter.id,
      email_address: "staff@example.nz", role: "staff", token_digest: "digest", expires_at: 7.days.from_now }
    expect { Invitation.insert_all!([ values ]) }.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it "rejects Owner invitations and non-owner inviters" do
    inviter = Membership.create!(user: user, business: business, role: "scheduler")
    invitation = Invitation.new(business: inviter.business, inviting_membership: inviter,
      email_address: "staff@example.nz", role: "owner", token_digest: "digest", expires_at: 7.days.from_now)
    expect(invitation).not_to be_valid
    expect(invitation.errors[:role]).not_to be_empty
    expect(invitation.errors[:inviting_membership]).not_to be_empty
  end

  it "destroys sessions when their user is deleted" do
    account = user
    session = account.sessions.create!
    account.destroy!
    expect(Session.exists?(session.id)).to be(false)
  end
end
