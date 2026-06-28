# frozen_string_literal: true

class AddManagementFieldsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :open_to_all_users, :boolean, default: false, null: false
    add_column :projects, :product_version, :string
    add_column :projects, :development_status, :string
    add_column :projects, :product_info, :json
    add_column :projects, :test_plan, :json
  end
end
