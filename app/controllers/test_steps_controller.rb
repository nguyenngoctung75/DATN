class TestStepsController < ApplicationController
  before_action :set_test_case
  before_action :set_test_step, except: [ :create ]
  before_action :require_project_membership!
  authorize_resource

  def create
    @test_step = @test_case.test_steps.build(
      step_number: @test_case.test_steps.count + 1
    )

    @test_step.test_step_contents.build(content_category: 'action', content_type: 'text',
content_value: 'Click to enter action...', display_order: 1)
    @test_step.test_step_contents.build(content_category: 'expectation', content_type: 'text',
content_value: 'Click to enter expected result...', display_order: 1)

    if @test_step.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to project_task_test_case_path(@project, @task, @test_case) }
      end
    else
      Rails.logger.error "Failed to create TestStep: #{@test_step.errors.full_messages.join(', ')}"
      redirect_to project_task_test_case_path(@project, @task, @test_case),
                  alert: "Failed to create test step: #{@test_step.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    @test_step.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_task_test_case_path(@project, @task, @test_case),
                                notice: 'Test step deleted and remaining steps renumbered.' }
    end
  end

  private

  def set_test_case
    @project = Project.find(params[:project_id])
    @task = @project.tasks.find(params[:task_id])
    @test_case = @task.test_cases.find(params[:test_case_id])
  end

  def set_test_step
    @test_step = @test_case.test_steps.find(params[:id])
  end

  def test_step_params
    params.require(:test_step).permit(
      :step_number,
      :description,
      :display_order,
      test_step_contents_attributes: %i[
        id
        content_type
        content_value
        content_category
        is_expected
        display_order
        _destroy
      ]
    )
  end
end
