module TestCaseImport
  class DeviceResultBuilder
    def initialize(test_case, device_results)
      @test_case = test_case
      @device_results = device_results
    end

    def build
      return if @device_results.blank?

      @device_results.each do |result|
        @test_case.test_results.create!(
          device: result[:device],
          status: result[:status],
          run_id: nil,
          executed_at: Time.current
        )
      end
    end
  end
end
