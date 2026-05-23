class CreateBugs < ActiveRecord::Migration[8.0]
  def change
    create_table :bugs do |t|
      t.integer :task_id, null: false
      t.integer :dev_id
      t.integer :tester_id
      t.string :title, null: false
      t.text :description
      t.string :category, null: false
      t.string :priority, null: false
      t.string :status, null: false, default: 'new'

      # Các trường mới cho spreadsheet import
      t.text :content # Nội dung chi tiết bug từ spreadsheet
      t.string :application # Ứng dụng (SP + PC, APP, etc.)
      t.string :image_video_url # URL hình ảnh/video
      t.text :notes # Ghi chú
      t.string :clock # Thời gian
      t.integer :test_result_id # ID test result liên quan

      t.datetime :deleted_at

      t.timestamps
    end

    add_index :bugs, :task_id
    add_index :bugs, :dev_id
    add_index :bugs, :tester_id
    add_index :bugs, :category
    add_index :bugs, :priority
    add_index :bugs, :status
    add_index :bugs, :deleted_at
    add_index :bugs, :application
    add_index :bugs, :test_result_id
  end
end
