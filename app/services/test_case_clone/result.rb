# frozen_string_literal: true

module TestCaseClone
  class Result
    attr_reader :count, :ids, :error, :import_run

    def self.success(count:, ids:, import_run: nil)
      new(success: true, count: count, ids: ids, import_run: import_run)
    end

    def self.failure(error:, import_run: nil)
      new(success: false, error: error, import_run: import_run)
    end

    def self.async(import_run:)
      new(success: true, async: true, import_run: import_run)
    end

    def initialize(success:, count: 0, ids: [], error: nil, import_run: nil, async: false)
      @success = success
      @count = count
      @ids = ids
      @error = error
      @import_run = import_run
      @async = async
    end

    def success?
      @success
    end

    def async?
      @async
    end
  end
end
