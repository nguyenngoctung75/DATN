require 'rails_helper'

RSpec.describe 'AppConfigurations', type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    login_as admin, scope: :user
    allow(RedmineService).to receive(:get_projects_list).and_return([])
  end

  it 'persists AI configuration fields' do
    patch app_configuration_path, params: {
      app_configuration: {
        ai_tc_enabled: '1',
        ai_model: 'gemini-2.0-flash',
        ai_tc_system_prompt: 'Custom prompt'
      }
    }
    config = AppConfiguration.instance
    expect(config.ai_tc_enabled).to be(true)
    expect(config.ai_model).to eq('gemini-2.0-flash')
    expect(config.ai_tc_system_prompt).to eq('Custom prompt')
  end
end
