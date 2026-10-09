class Business < ApplicationRecord
  has_many :memberships
  has_many :invitations
  validates :name, :slug, :trial_started_at, presence: true
  validates :slug, uniqueness: true
  validates :industry, inclusion: { in: %w[cleaning detailing] }
  validates :timezone, inclusion: { in: %w[Pacific/Auckland Pacific/Chatham] }
  validates :currency, inclusion: { in: [ "NZD" ] }
  attr_readonly :trial_started_at

  def self.generate_slug(name)
    "#{name.to_s.parameterize.presence || 'business'}-#{SecureRandom.hex(6)}"
  end
end
