class RemovePublicShortener < ActiveRecord::Migration[8.1]
  def up
    # Remove any public shortener account (kind = 1). Database-level
    # ON DELETE CASCADE constraints clean up its links and their visits and
    # taggings, plus tags, custom domains, API tokens, users, and profiles.
    execute "DELETE FROM accounts WHERE kind = 1"

    remove_check_constraint :links, name: "links_public_privacy_check"

    remove_check_constraint :links, name: "links_source_check"
    add_check_constraint :links, "source IN (0, 1)", name: "links_source_check"

    remove_check_constraint :accounts, name: "accounts_kind_check"
    remove_column :accounts, :kind
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
