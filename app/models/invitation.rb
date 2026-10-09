class Invitation < ApplicationRecord
  belongs_to :business
  belongs_to :inviting_membership, class_name: "Membership"
  normalizes :email_address, with: ->(email) { email.strip.downcase }
  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: %w[scheduler staff] }
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validate :inviter_belongs_to_business

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def rotate_token!
    with_lock do
      return nil if accepted_at? || revoked_at?
      token = SecureRandom.urlsafe_base64(32)
      update!(token_digest: self.class.digest(token), expires_at: 7.days.from_now)
      token
    end
  end

  def revoke!
    with_lock { update!(revoked_at: Time.current) unless accepted_at? || revoked_at? }
  end

  def available?
    !accepted_at? && !revoked_at? && expires_at > Time.current
  end

  def accept!(user, token)
    user.with_lock do
      with_lock do
        unless available? && ActiveSupport::SecurityUtils.secure_compare(token_digest, self.class.digest(token)) &&
            user.email_verified_at? && user.email_address == email_address && !Membership.exists?(user_id: user.id)
          return false
        end
        Membership.create!(user: user, business: business, role: role, status: "active")
        update!(accepted_at: Time.current)
      end
    end
    true
  end

  private
    def inviter_belongs_to_business
      unless inviting_membership&.business_id == business_id && inviting_membership&.role == "owner"
        errors.add(:inviting_membership, "must be an owner of this business")
      end
    end
end
