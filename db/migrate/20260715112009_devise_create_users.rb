# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.integer :kind, null: false, default: 0
      t.string :key, null: false
      t.timestamps

      t.index :key, unique: true
      t.check_constraint "kind IN (0, 1)", name: "accounts_kind_check"
      t.check_constraint "key = lower(key) AND char_length(key) > 0", name: "accounts_key_normalized_check"
    end

    create_table :users do |t|
      t.references :account, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :username, null: false

      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email

      t.timestamps null: false

      t.index "lower(email)", unique: true, name: "index_users_on_lower_email"
      t.index "lower(username)", unique: true, name: "index_users_on_lower_username"
      t.index :reset_password_token, unique: true
      t.index :confirmation_token, unique: true
      t.check_constraint "username = lower(username)", name: "users_username_lowercase_check"
      t.check_constraint "username ~ '^[a-z0-9_]+$'", name: "users_username_format_check"
      t.check_constraint "char_length(username) BETWEEN 3 AND 30", name: "users_username_length_check"
    end

    create_table :profiles do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :first_name
      t.string :last_name
      t.text :bio
      t.string :timezone, null: false, default: "UTC"
      t.boolean :public_enabled, null: false, default: false
      t.timestamps

      t.check_constraint "char_length(first_name) <= 100", name: "profiles_first_name_length_check"
      t.check_constraint "char_length(last_name) <= 100", name: "profiles_last_name_length_check"
      t.check_constraint "char_length(bio) <= 500", name: "profiles_bio_length_check"
    end
  end
end
