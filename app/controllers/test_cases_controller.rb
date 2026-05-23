class TestCasesController < ApplicationController
  before_action :set_task
  before_action :set_test_case, except: %i[create import_from_sheet clone_bulk]
  authorize_resource

  TC_HISTORY_FIELDS = %w[title test_type target note content_value group_description].freeze

  # GET /projects/:project_id/tasks/:task_id/test_cases/:id/edit
  def edit
    set_existing_titles
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # POST /projects/:project_id/tasks/:task_id/test_cases
  def create
    @test_case = @task.test_cases.build(test_case_params)
    @test_case.created_by = current_user
    apply_insert_position(@test_case)

    if @test_case.save
      @tc_sort = params[:tc_sort] == 'desc' ? 'desc' : 'asc'
      @show_archived = params[:show_archived] == '1'
      params[:tc_page] = TestCase.page_index_for(
        @test_case.id,
        task: @task,
        sort: @tc_sort,
        show_archived: @show_archived
      )

      set_existing_titles
      set_spreadsheet_data
      respond_to { |format| respond_test_case_created_success(format) }
    else
      set_existing_titles
      respond_to { |format| respond_test_case_created_failure(format) }
    end
  end

  # PATCH/PUT /projects/:project_id/tasks/:task_id/test_cases/:id
  def update
    @test_case.skip_title_sync = true if params[:skip_title_sync].present?
    if @test_case.update(test_case_params)
      set_existing_titles
      set_spreadsheet_data
      respond_to do |format|
        format.html do
          redirect_to [ @task.project, @task, @test_case ],
                      notice: 'Test case updated successfully.'
        end
        format.turbo_stream
        format.json { render json: @test_case }
      end
    else
      set_existing_titles
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
        format.json do
          render json: { errors: @test_case.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /projects/:project_id/tasks/:task_id/test_cases/:id
  def destroy
    @test_case.destroy
    set_spreadsheet_data
    respond_to do |format|
      format.html do
        redirect_to project_task_path(@task.project, @task),
                    notice: 'Test case deleted successfully.'
      end
      format.turbo_stream { render :soft_delete }
      format.json { head :no_content }
    end
  end

  # PATCH /projects/:project_id/tasks/:task_id/test_cases/:id/soft_delete
  def soft_delete
    @test_case.soft_delete!
    set_spreadsheet_data
    respond_to do |format|
      format.html do
        redirect_to project_task_path(@task.project, @task),
                    notice: 'Test case soft deleted successfully.'
      end
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  # PATCH /projects/:project_id/tasks/:task_id/test_cases/:id/restore
  def restore
    @test_case.restore!
    set_spreadsheet_data
    respond_to do |format|
      format.html do
        redirect_to project_task_path(@task.project, @task),
                    notice: 'Test case restored successfully.'
      end
      format.turbo_stream { render :soft_delete }
      format.json { head :no_content }
    end
  end

  # GET /projects/:project_id/tasks/:task_id/test_cases/:id/cell_history
  def cell_history
    field = params[:field].to_s
    return render json: { error: 'Invalid field' },
status: :unprocessable_entity unless TC_HISTORY_FIELDS.include?(field)

    logs =
      if field == 'content_value' && params[:content_id].present?
        ActivityLog.where(trackable_type: 'TestStepContent', trackable_id: params[:content_id])
      else
        step_ids = @test_case.test_steps.pluck(:id)
        ActivityLog.where(
          "(trackable_type='TestCase' AND trackable_id=?) OR (trackable_type='TestStep' AND trackable_id IN (?))",
          @test_case.id, step_ids
        )
      end

    logs = logs.includes(:user).order(created_at: :desc).to_a
               .select { |l| l.metadata.is_a?(Hash) && l.metadata.key?(field) }

    render json: CellHistorySerializer.call(logs, field)
  end

  # POST /projects/:project_id/tasks/:task_id/test_cases/:id/revert
  def revert
    log = ActivityLog.where(trackable: @test_case).find(params[:log_id])
    result = RecordRevertService.new(activity_log: log, field: params[:field]).call

    if result.success?
      set_spreadsheet_data
      flash.now[:notice] = "Reverted #{params[:field]} to '#{result.old_value}'"
    else
      flash.now[:alert] = result.error_message
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_task_path(@project, @task), notice: flash.now[:notice] }
    end
  end

  # POST /projects/:project_id/tasks/:task_id/test_cases/:id/clone
  def clone
    result = TestCaseClone::Dispatcher.new(
      source_task: @task,
      source_ids: [ @test_case.id ],
      destination_task_id: params[:destination_task_id],
      options: clone_options_param,
      user: current_user
    ).call
    handle_clone_result(result)
  end

  # POST /projects/:project_id/tasks/:task_id/test_cases/clone_bulk
  def clone_bulk
    result = TestCaseClone::Dispatcher.new(
      source_task: @task,
      source_ids: params[:source_ids],
      destination_task_id: params[:destination_task_id],
      options: clone_options_param,
      user: current_user
    ).call
    handle_clone_result(result)
  end

  # POST /projects/:project_id/tasks/:task_id/test_cases/import_from_sheet
  def import_from_sheet
    spreadsheet_id = extract_spreadsheet_id(params[:spreadsheet_id])

    if spreadsheet_id.blank?
      handle_missing_spreadsheet_id
      return
    end

    run = @task.project.import_runs.create!(
      import_type: 'manual_tc',
      status: 'pending',
      triggered_by: current_user,
      params: {
        'task_id' => @task.id,
        'spreadsheet_id' => spreadsheet_id,
        'wipe_existing' => params[:wipe_existing] == '1'
      }
    )
    TcImportJob.perform_later(run.id)

    respond_to do |format|
      format.html { redirect_to import_run_path(run), notice: 'Test case import queued. Running in background.' }
      format.json { render json: { import_run_id: run.id }, status: :accepted }
    end
  end

  private

  def clone_options_param
    raw = params[:options] || {}
    raw = raw.permit(:append_copy_suffix, :place_at_top) if raw.respond_to?(:permit)
    {
      append_copy_suffix: ActiveModel::Type::Boolean.new.cast(raw[:append_copy_suffix]),
      place_at_top: ActiveModel::Type::Boolean.new.cast(raw[:place_at_top])
    }
  end

  def handle_clone_result(result)
    if result.async?
      respond_to do |format|
        format.html { redirect_to import_run_path(result.import_run), notice: 'Cloning queued. Running in background.' }
        format.json { render json: { import_run_id: result.import_run.id }, status: :accepted }
      end
    elsif result.success?
      set_spreadsheet_data
      respond_to do |format|
        format.html do
          redirect_to project_task_path(@task.project, @task),
                      notice: "Cloned #{result.count} test case(s) successfully."
        end
        format.json { render json: { cloned_count: result.count, ids: result.ids } }
      end
    else
      respond_to do |format|
        format.html { redirect_to project_task_path(@task.project, @task), alert: result.error }
        format.json { render json: { error: result.error }, status: :unprocessable_entity }
      end
    end
  end

  def apply_insert_position(test_case)
    return unless params[:insert_after].present?

    after_tc = @task.test_cases.find_by(id: params[:insert_after])
    return unless after_tc&.position

    new_position = after_tc.position + 1
    TestCase.insert_at_position!(@task, new_position)
    test_case.position = new_position
  end

  def respond_test_case_created_success(format)
    format.html { redirect_to project_task_path(@task.project, @task), notice: 'Test case created successfully.' }
    format.turbo_stream { render :soft_delete }
    format.json { render json: @test_case, status: :created }
  end

  def respond_test_case_created_failure(format)
    format.turbo_stream do
      msg = "Failed to create test case: #{@test_case.errors.full_messages.join(', ')}"
      render turbo_stream: turbo_stream.prepend('flash-messages', partial: 'shared/flash',
                                                locals: { flash: { alert: msg } })
    end
    format.json { render json: { errors: @test_case.errors.full_messages }, status: :unprocessable_entity }
  end

  def set_spreadsheet_data
    @test_cases_per_page = 10
    @test_cases_page = [ params[:tc_page].to_i, 1 ].max
    @tc_sort = params[:tc_sort] == 'desc' ? 'desc' : 'asc'
    @show_archived = params[:show_archived] == '1'

    @all_test_cases = @task.test_cases_ordered(sort: @tc_sort, show_archived: @show_archived)
    @total_test_cases = @all_test_cases.size
    @total_tc_pages = (@total_test_cases.to_f / @test_cases_per_page).ceil
    @test_cases_page = @total_tc_pages if @total_tc_pages.positive? && @test_cases_page > @total_tc_pages

    tc_start = (@test_cases_page - 1) * @test_cases_per_page
    @paginated_test_cases = @all_test_cases.limit(@test_cases_per_page).offset(tc_start).to_a
    @devices = @task.unique_devices.presence || %w[pc sp app]
    @tc_start_index = tc_start
  end

  def extract_spreadsheet_id(input)
    return input if input.blank?

    # Extract ID from Google Sheets URL if present
    if input.include?('docs.google.com/spreadsheets/d/')
      match = input.match(%r{/d/([^/]+)})
      match ? match[1] : input
    else
      input.strip
    end
  end

  def handle_missing_spreadsheet_id
    respond_to do |format|
      format.html { redirect_to [ @task.project, @task ], alert: 'Please provide Google Sheet ID.' }
      format.json { render json: { error: 'Spreadsheet ID is required' }, status: :unprocessable_entity }
    end
  end

  def set_task
    @task = Task.find(params[:task_id]) if params[:task_id]
    @project = @task&.project
  end

  def set_test_case
    @test_case = TestCase.find(params[:id])
    @task = @test_case.task if @task.nil?
    @project = @task&.project if @project.nil?
  end

  def set_existing_titles
    @existing_titles = @task&.test_cases&.active&.pluck(:title)&.uniq&.compact&.sort || []
  end

  def test_case_params
    params.require(:test_case).permit(
      :title, :description, :group_description, :test_type, :target, :note,
      test_step_attributes: test_steps_params
    )
  end

  def test_steps_params
    [
      :id, :step_number, :description, :display_order, :_destroy,
      { test_step_contents_attributes: test_step_contents_params }
    ]
  end

  def test_step_contents_params
    %i[id content_type content_value content_category is_expected display_order _destroy]
  end
end
