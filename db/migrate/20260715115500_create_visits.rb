class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.references :link, null: false, foreign_key: { on_delete: :cascade }
      t.string :event_key, null: false
      t.string :visitor_digest, null: false, limit: 64
      t.string :browser, limit: 100
      t.string :device_type, limit: 100
      t.string :country_code, limit: 2
      t.string :referrer_host, limit: 253
      t.datetime :occurred_at, null: false

      t.index :event_key, unique: true
      t.index [ :link_id, :occurred_at ]
      t.index [ :link_id, :visitor_digest, :occurred_at ], name: "index_visits_on_link_visitor_and_time"
      t.check_constraint "visitor_digest ~ '^[a-f0-9]{64}$'", name: "visits_digest_format_check"
      t.check_constraint "country_code IS NULL OR country_code ~ '^[A-Z]{2}$'", name: "visits_country_code_check"
      t.check_constraint "char_length(browser) <= 100", name: "visits_browser_length_check"
      t.check_constraint "char_length(device_type) <= 100", name: "visits_device_length_check"
      t.check_constraint "char_length(referrer_host) <= 253", name: "visits_referrer_length_check"
    end
  end
end
