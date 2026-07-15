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

ActiveRecord::Schema[8.1].define(version: 2026_07_15_115500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.integer "kind", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_accounts_on_key", unique: true
    t.check_constraint "key::text = lower(key::text) AND char_length(key::text) > 0", name: "accounts_key_normalized_check"
    t.check_constraint "kind = ANY (ARRAY[0, 1])", name: "accounts_kind_check"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "revoked_at"], name: "index_api_tokens_on_account_id_and_revoked_at"
    t.index ["account_id"], name: "index_api_tokens_on_account_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.check_constraint "char_length(name::text) >= 1 AND char_length(name::text) <= 80", name: "api_tokens_name_length_check"
    t.check_constraint "char_length(token_prefix::text) >= 4 AND char_length(token_prefix::text) <= 20", name: "api_tokens_prefix_length_check"
    t.check_constraint "token_digest::text ~ '^[a-f0-9]{64}$'::text", name: "api_tokens_digest_format_check"
  end

  create_table "custom_domains", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "dns_target"
    t.text "fallback_url"
    t.string "hostname", null: false
    t.datetime "last_checked_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "verification_token", null: false
    t.datetime "verified_at"
    t.index "lower((hostname)::text)", name: "index_custom_domains_on_lower_hostname", unique: true
    t.index ["account_id"], name: "index_custom_domains_on_account_id"
    t.index ["verification_token"], name: "index_custom_domains_on_verification_token", unique: true
    t.check_constraint "hostname::text = lower(hostname::text) AND char_length(hostname::text) >= 1 AND char_length(hostname::text) <= 253", name: "custom_domains_hostname_check"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "custom_domains_status_check"
  end

  create_table "links", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "custom_domain_id"
    t.text "destination_url", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "source", default: 0, null: false
    t.boolean "tracking_enabled", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_links_on_account_id_and_created_at"
    t.index ["account_id", "source"], name: "index_links_on_account_id_and_source"
    t.index ["account_id"], name: "index_links_on_account_id"
    t.index ["custom_domain_id", "slug"], name: "index_links_on_custom_domain_and_slug", unique: true
    t.index ["custom_domain_id"], name: "index_links_on_custom_domain_id"
    t.index ["slug"], name: "index_links_on_primary_slug", unique: true, where: "(custom_domain_id IS NULL)"
    t.check_constraint "NOT (source = 2 AND (custom_domain_id IS NOT NULL OR tracking_enabled))", name: "links_public_privacy_check"
    t.check_constraint "char_length(destination_url) >= 1 AND char_length(destination_url) <= 2048", name: "links_destination_length_check"
    t.check_constraint "char_length(name::text) >= 1 AND char_length(name::text) <= 255", name: "links_name_length_check"
    t.check_constraint "char_length(slug::text) >= 3 AND char_length(slug::text) <= 64", name: "links_slug_length_check"
    t.check_constraint "slug::text = lower(slug::text) AND slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text", name: "links_slug_format_check"
    t.check_constraint "source = ANY (ARRAY[0, 1, 2])", name: "links_source_check"
  end

  create_table "profiles", force: :cascade do |t|
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.boolean "public_enabled", default: false, null: false
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
    t.check_constraint "char_length(bio) <= 500", name: "profiles_bio_length_check"
    t.check_constraint "char_length(first_name::text) <= 100", name: "profiles_first_name_length_check"
    t.check_constraint "char_length(last_name::text) <= 100", name: "profiles_last_name_length_check"
  end

  create_table "taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "link_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["link_id", "tag_id"], name: "index_taggings_on_link_id_and_tag_id", unique: true
    t.index ["link_id"], name: "index_taggings_on_link_id"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_tags_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_tags_on_account_id"
    t.check_constraint "name::text = lower(name::text) AND char_length(name::text) >= 1 AND char_length(name::text) <= 40", name: "tags_name_check"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
    t.index ["account_id"], name: "index_users_on_account_id", unique: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.check_constraint "char_length(username::text) >= 3 AND char_length(username::text) <= 30", name: "users_username_length_check"
    t.check_constraint "username::text = lower(username::text)", name: "users_username_lowercase_check"
    t.check_constraint "username::text ~ '^[a-z0-9_]+$'::text", name: "users_username_format_check"
  end

  create_table "visits", force: :cascade do |t|
    t.string "browser", limit: 100
    t.string "country_code", limit: 2
    t.string "device_type", limit: 100
    t.string "event_key", null: false
    t.bigint "link_id", null: false
    t.datetime "occurred_at", null: false
    t.string "referrer_host", limit: 253
    t.string "visitor_digest", limit: 64, null: false
    t.index ["event_key"], name: "index_visits_on_event_key", unique: true
    t.index ["link_id", "occurred_at"], name: "index_visits_on_link_id_and_occurred_at"
    t.index ["link_id", "visitor_digest", "occurred_at"], name: "index_visits_on_link_visitor_and_time"
    t.index ["link_id"], name: "index_visits_on_link_id"
    t.check_constraint "char_length(browser::text) <= 100", name: "visits_browser_length_check"
    t.check_constraint "char_length(device_type::text) <= 100", name: "visits_device_length_check"
    t.check_constraint "char_length(referrer_host::text) <= 253", name: "visits_referrer_length_check"
    t.check_constraint "country_code IS NULL OR country_code::text ~ '^[A-Z]{2}$'::text", name: "visits_country_code_check"
    t.check_constraint "visitor_digest::text ~ '^[a-f0-9]{64}$'::text", name: "visits_digest_format_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "accounts", on_delete: :cascade
  add_foreign_key "custom_domains", "accounts", on_delete: :cascade
  add_foreign_key "links", "accounts", on_delete: :cascade
  add_foreign_key "links", "custom_domains", on_delete: :nullify
  add_foreign_key "profiles", "users", on_delete: :cascade
  add_foreign_key "taggings", "links", on_delete: :cascade
  add_foreign_key "taggings", "tags", on_delete: :cascade
  add_foreign_key "tags", "accounts", on_delete: :cascade
  add_foreign_key "users", "accounts", on_delete: :cascade
  add_foreign_key "visits", "links", on_delete: :cascade
end
