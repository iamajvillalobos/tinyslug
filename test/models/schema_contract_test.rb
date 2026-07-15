require "test_helper"

class SchemaContractTest < ActiveSupport::TestCase
  FOREIGN_KEYS = {
    api_tokens: :accounts,
    custom_domains: :accounts,
    links: %i[accounts custom_domains],
    profile_links: %i[profiles links],
    profiles: :users,
    social_links: :profiles,
    taggings: %i[links tags],
    tags: :accounts,
    users: :accounts,
    visits: :links
  }.freeze

  UNIQUE_INDEXES = {
    accounts: [ :key ],
    api_tokens: [ :token_digest ],
    custom_domains: [ :verification_token ],
    profile_links: %i[profile_id link_id],
    profiles: [ :user_id ],
    taggings: %i[link_id tag_id],
    tags: %i[account_id name],
    users: [ :account_id ],
    visits: [ :event_key ]
  }.freeze

  test "every application association has a database foreign key" do
    FOREIGN_KEYS.each do |from_table, target_tables|
      actual_targets = ActiveRecord::Base.connection.foreign_keys(from_table).map { |foreign_key| foreign_key.to_table.to_sym }
      Array(target_tables).each do |target_table|
        assert_includes actual_targets, target_table, "Missing #{from_table} -> #{target_table} foreign key"
      end
    end
  end

  test "identity and join invariants have unique indexes" do
    UNIQUE_INDEXES.each do |table, columns|
      assert ActiveRecord::Base.connection.index_exists?(table, columns, unique: true), "Missing unique index on #{table}(#{columns.join(', ')})"
    end

    assert ActiveRecord::Base.connection.index_exists?(:links, :slug, unique: true, where: "custom_domain_id IS NULL")
    assert ActiveRecord::Base.connection.index_exists?(:links, %i[custom_domain_id slug], unique: true)
  end
end
