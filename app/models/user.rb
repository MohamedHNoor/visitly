class User < ApplicationRecord
  generates_token_for :email_verification, expires_in: 24.hours do
    [ verification_nonce, email_verified_at ]
  end
  generates_token_for :password_recovery, expires_in: 15.minutes do
    [ reset_nonce, password_salt&.last(10) ]
  end

  MINIMUM_PASSWORD_LENGTH = 8

  has_secure_password
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true
  validate :password_includes_number_and_special_character, if: -> { password.present? }
  normalizes :email_address, with: ->(email) { email.strip.downcase }
  has_many :sessions, dependent: :destroy
  has_one :membership
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :display_name, presence: true

  def issue_verification_token!
    with_lock do
      update!(verification_nonce: SecureRandom.hex(32))
      generate_token_for(:email_verification)
    end
  end

  def issue_reset_token!
    with_lock do
      update!(reset_nonce: SecureRandom.hex(32))
      generate_token_for(:password_recovery)
    end
  end

  def verify_email!(token)
    with_lock do
      return false if email_verified_at? || self.class.find_by_token_for(:email_verification, token)&.id != id
      update!(email_verified_at: Time.current, verification_nonce: nil)
    end
    true
  end

  def reset_password!(token, attributes)
    with_lock do
      return false if self.class.find_by_token_for(:password_recovery, token)&.id != id
      assign_attributes(attributes)
      return false if password.blank? || !valid?
      self.reset_nonce = nil
      save!
      sessions.destroy_all
    end
    true
  end

  def create_workspace!(attributes)
    with_lock do
      unless email_verified_at?
        errors.add(:email_verified_at, "must be verified before creating a workspace")
        raise ActiveRecord::RecordInvalid, self
      end
      existing = Membership.find_by(user_id: id)
      return existing.business if existing

      business = Business.create!(attributes.slice(:name, :industry, :timezone).merge(
        slug: Business.generate_slug(attributes[:name]), currency: "NZD", trial_started_at: Time.current))
      Membership.create!(user: self, business: business, role: "owner", status: "active")
      business
    end
  end

  private
    def password_includes_number_and_special_character
      errors.add(:password, "must include a number") unless password.match?(/\d/)
      errors.add(:password, "must include a special character") unless password.match?(/[^[:alnum:]]/)
    end
end
