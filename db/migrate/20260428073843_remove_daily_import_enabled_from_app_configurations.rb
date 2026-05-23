class RemoveDailyImportEnabledFromAppConfigurations < ActiveRecord::Migration[8.0]
  def change
    remove_column :app_configurations, :daily_import_enabled, :boolean
  end
end
