class RecordRevertService
  Result = Struct.new(:success?, :db_field, :old_value, :error_message, keyword_init: true)

  def initialize(record: nil, activity_log:, field:)
    @record = record || activity_log.trackable
    @log = activity_log
    @field = field
  end

  def call
    trackable = @log.trackable
    unless @log.metadata[@field] && trackable
      return failure("Could not find history data for #{@field}")
    end

    db_field = resolve_db_field(trackable)
    return failure("Cannot revert '#{@field}': unsupported field") unless db_field

    old_value = @log.metadata[@field][0]
    if trackable.update(db_field => old_value)
      Result.new(success?: true, db_field: db_field, old_value: old_value)
    else
      failure("Failed to revert: #{trackable.errors.full_messages.join(', ')}")
    end
  end

  private

  def resolve_db_field(trackable)
    snake = @field.downcase.gsub(' ', '_')
    [@field, snake, "#{snake}_id"].find { |f| trackable.class.column_names.include?(f) }
  end

  def failure(message)
    Result.new(success?: false, error_message: message)
  end
end
