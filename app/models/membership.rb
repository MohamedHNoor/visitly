class Membership < ApplicationRecord
  belongs_to :business
  belongs_to :user
  validates :user_id, uniqueness: true
  validates :role, inclusion: { in: %w[owner scheduler staff] }
  validates :status, inclusion: { in: [ "active" ] }
end
