class TestCasePresenter < SimpleDelegator
  TEST_TYPE_LABELS = { 'feature' => 'Feature', 'ui' => 'UI', 'data' => 'Data' }.freeze
  TARGET_LABELS = {
    'pc_sp' => 'PC・SP', 'pc_sp_app' => 'PC・SP・APP',
    'app' => 'APP', 'pc' => 'PC', 'sp' => 'SP'
  }.freeze

  def test_type_display
    TEST_TYPE_LABELS[test_type] || test_type&.titleize || 'N/A'
  end

  def target_display
    TARGET_LABELS[target] || target&.upcase || 'N/A'
  end

  def parsed_device_results
    test_results.active.map do |result|
      { device: result.device || 'Unknown', status: result.status || 'unknown' }
    end
  end
end
