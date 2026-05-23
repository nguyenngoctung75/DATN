# frozen_string_literal: true

class ProjectRedminePerProject < ActiveRecord::Migration[8.0]
  def up
    add_column :projects, :redmine_project_id, :string

    # Migrate: each project in join table gets the current config's redmine_project_id
    if table_exists?(:app_configuration_target_projects) && column_exists?(:app_configurations, :redmine_project_id)
      row = connection.select_one("SELECT redmine_project_id FROM app_configurations LIMIT 1")
      redmine_id = row && row["redmine_project_id"]
      if redmine_id.present?
        project_ids = connection.select_values("SELECT project_id FROM app_configuration_target_projects")
        if project_ids.any?
          quoted_id = connection.quote(redmine_id)
          id_list = project_ids.map { |id| connection.quote(id) }.join(",")
          execute("UPDATE projects SET redmine_project_id = #{quoted_id} WHERE id IN (#{id_list})")
        end
      end
    end

    remove_column :app_configurations, :redmine_project_id if column_exists?(:app_configurations, :redmine_project_id)
    drop_table :app_configuration_target_projects if table_exists?(:app_configuration_target_projects)
  end

  def down
    create_table :app_configuration_target_projects do |t|
      t.references :app_configuration, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.timestamps
    end
    add_index :app_configuration_target_projects, %i[app_configuration_id project_id],
              unique: true, name: "index_app_config_target_projects_unique"

    add_column :app_configurations, :redmine_project_id, :string
    remove_column :projects, :redmine_project_id
  end
end
