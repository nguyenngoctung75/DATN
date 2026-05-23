class SyncGroupedTitlesBroadcastJob < ApplicationJob
  queue_as :default

  def perform(task_id, sibling_ids, new_value, field: 'title')
    task = Task.find_by(id: task_id)
    return unless task

    sibling_ids.each do |s_id|
      Turbo::StreamsChannel.broadcast_update_to(
        task,
        target: "test-case-#{s_id}-#{field.dasherize}",
        html: new_value
      )
    end
  end
end
