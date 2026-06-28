class AddAiFieldsToAppConfigurations < ActiveRecord::Migration[8.0]
  def change
    add_column :app_configurations, :ai_tc_enabled, :boolean, default: false, null: false
    add_column :app_configurations, :ai_model, :string, default: "gemini-2.0-flash"
    add_column :app_configurations, :ai_tc_system_prompt, :text
  end
end
