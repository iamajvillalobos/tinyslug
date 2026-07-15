class CreateLinksAndTags < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_domains do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :hostname, null: false
      t.text :fallback_url
      t.integer :status, null: false, default: 0
      t.string :verification_token, null: false
      t.string :dns_target
      t.datetime :verified_at
      t.datetime :last_checked_at
      t.timestamps

      t.index "lower(hostname)", unique: true, name: "index_custom_domains_on_lower_hostname"
      t.index :verification_token, unique: true
      t.check_constraint "status IN (0, 1, 2)", name: "custom_domains_status_check"
      t.check_constraint "hostname = lower(hostname) AND char_length(hostname) BETWEEN 1 AND 253", name: "custom_domains_hostname_check"
    end

    create_table :links do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :custom_domain, foreign_key: { on_delete: :nullify }
      t.text :destination_url, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :tracking_enabled, null: false, default: false
      t.integer :source, null: false, default: 0
      t.timestamps

      t.index [ :account_id, :created_at ]
      t.index [ :account_id, :source ]
      t.index :slug, unique: true, where: "custom_domain_id IS NULL", name: "index_links_on_primary_slug"
      t.index [ :custom_domain_id, :slug ], unique: true, name: "index_links_on_custom_domain_and_slug"
      t.check_constraint "char_length(destination_url) BETWEEN 1 AND 2048", name: "links_destination_length_check"
      t.check_constraint "char_length(name) BETWEEN 1 AND 255", name: "links_name_length_check"
      t.check_constraint "slug = lower(slug) AND slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'", name: "links_slug_format_check"
      t.check_constraint "char_length(slug) BETWEEN 3 AND 64", name: "links_slug_length_check"
      t.check_constraint "source IN (0, 1, 2)", name: "links_source_check"
      t.check_constraint "NOT (source = 2 AND (custom_domain_id IS NOT NULL OR tracking_enabled))", name: "links_public_privacy_check"
    end

    create_table :tags do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.timestamps

      t.index [ :account_id, :name ], unique: true
      t.check_constraint "name = lower(name) AND char_length(name) BETWEEN 1 AND 40", name: "tags_name_check"
    end

    create_table :taggings do |t|
      t.references :link, null: false, foreign_key: { on_delete: :cascade }
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps

      t.index [ :link_id, :tag_id ], unique: true
    end
  end
end
