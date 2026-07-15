class CreatePublicProfileLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :profile_links do |t|
      t.references :profile, null: false, foreign_key: { on_delete: :cascade }
      t.references :link, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.timestamps

      t.index [ :profile_id, :link_id ], unique: true
      t.index [ :profile_id, :position ]
      t.check_constraint "position >= 0", name: "profile_links_position_check"
    end

    create_table :social_links do |t|
      t.references :profile, null: false, foreign_key: { on_delete: :cascade }
      t.string :label, null: false
      t.text :url, null: false
      t.integer :position, null: false
      t.timestamps

      t.index [ :profile_id, :position ]
      t.check_constraint "char_length(label) BETWEEN 1 AND 40", name: "social_links_label_length_check"
      t.check_constraint "position >= 0", name: "social_links_position_check"
    end
  end
end
