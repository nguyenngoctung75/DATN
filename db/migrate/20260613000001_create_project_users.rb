# frozen_string_literal: true

class CreateProjectUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :project_users do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :project_users, %i[project_id user_id], unique: true
  end
end
