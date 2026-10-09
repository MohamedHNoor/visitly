class CreateIdentityFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :display_name, null: false
      t.datetime :email_verified_at
      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_check_constraint :users, "email_address = lower(btrim(email_address)) AND email_address <> ''", name: "users_normalized_email"
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
    create_table :businesses, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :industry, null: false
      t.string :timezone, null: false
      t.string :currency, null: false, default: "NZD"
      t.datetime :trial_started_at, null: false
      t.timestamps
    end
    add_index :businesses, :slug, unique: true
    add_check_constraint :businesses, "industry IN ('cleaning', 'detailing')", name: "businesses_industry"
    add_check_constraint :businesses, "timezone IN ('Pacific/Auckland', 'Pacific/Chatham') AND currency = 'NZD'", name: "businesses_locale"
    create_table :memberships, id: :uuid do |t|
      t.references :business, type: :uuid, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :role, null: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :memberships, [ :business_id, :id ], unique: true
    add_check_constraint :memberships, "role IN ('owner', 'scheduler', 'staff') AND status = 'active'", name: "memberships_role_status"
    create_table :invitations, id: :uuid do |t|
      t.references :business, type: :uuid, null: false, foreign_key: true
      t.uuid :inviting_membership_id, null: false
      t.string :email_address, null: false
      t.string :role, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :invitations, :token_digest, unique: true
    add_index :invitations, [ :business_id, :inviting_membership_id ]
    add_foreign_key :invitations, :memberships, column: [ :business_id, :inviting_membership_id ], primary_key: [ :business_id, :id ]
    add_check_constraint :invitations, "role IN ('scheduler', 'staff')", name: "invitations_role"
    add_check_constraint :invitations, "email_address = lower(btrim(email_address)) AND email_address <> ''", name: "invitations_normalized_email"
  end
end
