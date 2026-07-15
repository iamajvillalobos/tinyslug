class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps

      t.index :token_digest, unique: true
      t.index [ :account_id, :revoked_at ]
      t.check_constraint "char_length(name) BETWEEN 1 AND 80", name: "api_tokens_name_length_check"
      t.check_constraint "token_digest ~ '^[a-f0-9]{64}$'", name: "api_tokens_digest_format_check"
      t.check_constraint "char_length(token_prefix) BETWEEN 4 AND 20", name: "api_tokens_prefix_length_check"
    end
  end
end
