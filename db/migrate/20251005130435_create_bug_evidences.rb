class CreateBugEvidences < ActiveRecord::Migration[8.0]
  def change
    create_table :bug_evidences do |t|
      t.integer :bug_id, null: false
      t.string :content_type, null: false
      t.text :content_value, null: false

      t.timestamps
    end

    add_index :bug_evidences, :bug_id
    add_index :bug_evidences, :content_type
  end
end
