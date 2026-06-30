class TestRunsController < ApplicationController
  before_action :set_task
  before_action :set_test_run, except: %i[index new create]
  before_action :require_project_membership!
  authorize_resource

  def index
    @test_runs = @task.test_runs.active.includes(:executed_by, :test_results).order(created_at: :desc)

    @test_runs = @test_runs.where(status: params[:status]) if params[:status].present?

    respond_to do |format|
      format.html
      format.json do
        render json: @test_runs.as_json(
          include: {
            executed_by: { only: %i[id name email] },
            test_results: {
              include: {
                test_case: { only: %i[id title] }
              }
            }
          },
          methods: %i[pass_count fail_count not_run_count pass_rate]
        )
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        render json: @test_run.as_json(
          include: {
            executed_by: { only: %i[id name email] },
            test_results: {
              include: {
                test_case: {
                  only: %i[id title],
                  include: :test_steps
                }
              }
            }
          },
          methods: %i[pass_count fail_count not_run_count pass_rate execution_duration_formatted]
        )
      end
    end
  end

  def new
    @test_run = @task.test_runs.build
    @test_cases = @task.test_cases.active
  end

  def edit
    @test_cases = @task.test_cases.active
  end

  def create
    @test_run = @task.test_runs.build(test_run_params)
    @test_run.executed_by = current_user
    @test_run.status ||= 'pending'

    if @test_run.save
      respond_to do |format|
        format.html do
          redirect_to [ @task.project, @task, @test_run ],
                      notice: 'Test run created successfully.'
        end
        format.json { render json: @test_run, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json do
          render json: { errors: @test_run.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
    end
  end

  def update
    if @test_run.update(test_run_params)
      respond_to do |format|
        format.html do
          redirect_to [ @task.project, @task, @test_run ],
                      notice: 'Test run updated successfully.'
        end
        format.json { render json: @test_run }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json do
          render json: { errors: @test_run.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @test_run.destroy
    respond_to do |format|
      format.html do
        redirect_to project_task_test_runs_path(@task.project, @task),
                    notice: 'Test run deleted successfully.'
      end
      format.json { head :no_content }
    end
  end

  def soft_delete
    @test_run.soft_delete!
    respond_to do |format|
      format.html do
        redirect_to project_task_test_runs_path(@task.project, @task),
                    notice: 'Test run soft deleted successfully.'
      end
      format.json { head :no_content }
    end
  end

  def start
    @test_run.start!
    respond_to do |format|
      format.html do
        redirect_to [ @task.project, @task, @test_run ],
                    notice: 'Test run started.'
      end
      format.json { render json: @test_run }
    end
  end

  def complete
    @test_run.complete!
    respond_to do |format|
      format.html do
        redirect_to [ @task.project, @task, @test_run ],
                    notice: 'Test run completed.'
      end
      format.json { render json: @test_run }
    end
  end

  def abort
    @test_run.abort!
    respond_to do |format|
      format.html do
        redirect_to [ @task.project, @task, @test_run ],
                    notice: 'Test run aborted.'
      end
      format.json { render json: @test_run }
    end
  end

  private

  def set_task
    @task = Task.find(params[:task_id]) if params[:task_id]
    @project = @task&.project
  end

  def set_test_run
    @test_run = TestRun.includes(:executed_by, test_results: :test_case).find(params[:id])
    @task = @test_run.task if @task.nil?
    @project = @task&.project if @project.nil?
  end

  def test_run_params
    params.require(:test_run).permit(
      :name,
      :description,
      :status,
      :executed_at
    )
  end
end
