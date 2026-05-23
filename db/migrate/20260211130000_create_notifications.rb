# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.string :category, null: false, default: "info"   # cronjob, system, info, etc.
      t.string :title, null: false
      t.text :message
      t.string :link
      t.timestamps
    end
    add_index :notifications, :created_at, order: { created_at: :desc }
    add_index :notifications, :category

    create_table :notification_reads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notification, null: false, foreign_key: true
      t.datetime :read_at, null: false
      t.timestamps
    end
    add_index :notification_reads, [ :user_id, :notification_id ], unique: true
  end
end
