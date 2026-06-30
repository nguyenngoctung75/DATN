class TestResultsController < ApplicationController
  before_action :set_test_case, except: [ :index ]
  before_action :set_test_result, except: %i[index new create]
  authorize_resource

  def index
    @test_results = TestResult.active.includes(:test_case, :test_run, :executed_by).order(executed_at: :desc)
    apply_filters

    respond_to do |format|
      format.html
      format.json { render json: index_json_response }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        render json: @test_result.as_json(
          include: {
            test_case: {
              include: {
                test_steps: {
                  include: :test_step_contents
                }
              }
            },
            test_run: { only: %i[id name status] },
            executed_by: { only: %i[id name email] }
          }
        )
      end
    end
  end

  def new
    @test_result = @test_case.test_results.build
    @test_result.device = params[:device] if params[:device].present?
  end

  def edit; end

  def create
    @test_result = @test_case.test_results.build(test_result_params)
    @test_result.executed_by = current_user
    @test_result.executed_at = Time.current

    if @test_result.save
      respond_to do |format|
        format.html do
          redirect_to [ @project, @task, @test_case ],
                      notice: 'Test result created successfully.'
        end
        format.turbo_stream
        format.json { render json: @test_result, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json do
          render json: { errors: @test_result.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
    end
  end

  def update
    if @test_result.update(test_result_params)
      respond_to do |format|
        format.html do
          redirect_to [ @test_case.task.project, @test_case.task, @test_case ],
                      notice: 'Test result updated successfully.'
        end
        format.json { render json: @test_result }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json do
          render json: { errors: @test_result.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @test_result.destroy
    respond_to do |format|
      format.html do
        redirect_to [ @test_case.task.project, @test_case.task, @test_case ],
                    notice: 'Test result deleted successfully.'
      end
      format.json { head :no_content }
    end
  end

  def soft_delete
    @test_result.soft_delete!
    respond_to do |format|
      format.html do
        redirect_to [ @test_case.task.project, @test_case.task, @test_case ],
                    notice: 'Test result soft deleted successfully.'
      end
      format.json { head :no_content }
    end
  end

  private

  def apply_filters
    @test_results = @test_results.where(status: params[:status]) if params[:status].present?
    @test_results = @test_results.where(run_id: params[:run_id]) if params[:run_id].present?
    @test_results = @test_results.where(case_id: params[:case_id]) if params[:case_id].present?
    @test_results = @test_results.for_task(params[:task_id]) if params[:task_id].present?
    @test_results = @test_results.for_project(params[:project_id]) if params[:project_id].present?
  end

  def index_json_response
    @test_results.as_json(
      include: {
        test_case: {
          only: %i[id title],
          include: {
            task: { only: %i[id title project_id] }
          }
        },
        test_run: { only: %i[id name] },
        executed_by: { only: %i[id name email] }
      }
    )
  end

  def set_test_case
    @test_case = TestCase.find(params[:test_case_id]) if params[:test_case_id]
    @task = @test_case&.task
    @project = @task&.project
  end

  def set_test_result
    @test_result = TestResult.find(params[:id])
    @test_case = @test_result.test_case if @test_case.nil?
    @task = @test_case&.task if @task.nil?
    @project = @task&.project if @project.nil?
  end

  def test_result_params
    params.require(:test_result).permit(
      :run_id,
      :status,
      :device,
      :executed_at
    )
  end
end
