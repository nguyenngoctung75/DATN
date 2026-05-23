class AddDeviceConfigToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :device_config, :string
  end
end
