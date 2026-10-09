# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_10_000200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "businesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "industry", null: false
    t.string "timezone", null: false
    t.string "currency", default: "NZD", null: false
    t.datetime "trial_started_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_businesses_on_slug", unique: true
    t.check_constraint "(timezone::text = ANY (ARRAY['Pacific/Auckland'::character varying, 'Pacific/Chatham'::character varying]::text[])) AND currency::text = 'NZD'::text", name: "businesses_locale"
    t.check_constraint "industry::text = ANY (ARRAY['cleaning'::character varying, 'detailing'::character varying]::text[])", name: "businesses_industry"
  end

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "business_id", null: false
    t.uuid "inviting_membership_id", null: false
    t.string "email_address", null: false
    t.string "role", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "inviting_membership_id"], name: "index_invitations_on_business_id_and_inviting_membership_id"
    t.index ["business_id"], name: "index_invitations_on_business_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
    t.check_constraint "email_address::text = lower(btrim(email_address::text)) AND email_address::text <> ''::text", name: "invitations_normalized_email"
    t.check_constraint "role::text = ANY (ARRAY['scheduler'::character varying, 'staff'::character varying]::text[])", name: "invitations_role"
  end

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "business_id", null: false
    t.bigint "user_id", null: false
    t.string "role", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "id"], name: "index_memberships_on_business_id_and_id", unique: true
    t.index ["business_id"], name: "index_memberships_on_business_id"
    t.index ["user_id"], name: "index_memberships_on_user_id", unique: true
    t.check_constraint "(role::text = ANY (ARRAY['owner'::character varying, 'scheduler'::character varying, 'staff'::character varying]::text[])) AND status::text = 'active'::text", name: "memberships_role_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "display_name", null: false
    t.datetime "email_verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "verification_nonce"
    t.string "reset_nonce"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "email_address::text = lower(btrim(email_address::text)) AND email_address::text <> ''::text", name: "users_normalized_email"
  end

  add_foreign_key "invitations", "businesses"
  add_foreign_key "invitations", "memberships", column: ["business_id", "inviting_membership_id"], primary_key: ["business_id", "id"]
  add_foreign_key "memberships", "businesses"
  add_foreign_key "memberships", "users"
  add_foreign_key "sessions", "users"
end
