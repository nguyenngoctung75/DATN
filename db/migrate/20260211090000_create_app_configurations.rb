# frozen_string_literal: true

class CreateAppConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :app_configurations do |t|
      t.boolean :daily_import_enabled, default: false, null: false
      t.string :redmine_project_id
      t.timestamps
    end

    create_table :app_configuration_target_projects do |t|
      t.references :app_configuration, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.timestamps
    end
    add_index :app_configuration_target_projects, %i[app_configuration_id project_id],
              unique: true, name: "index_app_config_target_projects_unique"
  end
end
