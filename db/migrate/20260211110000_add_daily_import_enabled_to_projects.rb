# frozen_string_literal: true

class AddDailyImportEnabledToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :daily_import_enabled, :boolean, default: false, null: false
  end
end
