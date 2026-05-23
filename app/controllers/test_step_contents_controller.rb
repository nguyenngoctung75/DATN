class TestStepContentsController < ApplicationController
  before_action :set_content

  def update
    authorize! :update, @content
    if @content.update(content_params)
      render json: @content.as_json(only: %i[id content_type content_value content_category is_expected
display_order]).merge(
        formatted_value: view_context.format_content_with_media_links(@content.content_value)
      )
    else
      render json: { errors: @content.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_content
    @content = TestStepContent.find(params[:id])
  end

  def content_params
    params.require(:test_step_content).permit(:content_value)
  end
end
