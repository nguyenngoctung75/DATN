# frozen_string_literal: true

require_relative 'content_library'

module Seeds
  # Dựng toàn bộ dữ liệu cho MỘT project theo layout cố định:
  #
  #   190 task CLOSED  = 95 (không subtask) + 95 (có 5 subtask)
  #   10  task OPEN    = 5 Nhóm C (có 5 subtask) + 5 Nhóm D (không subtask)
  #
  #   Nhóm A — 20 task closed có bug (10 ở nhánh không-subtask + 10 ở nhánh có-subtask)
  #   Nhóm C — 5 task open có bug
  #   Còn lại không bug.
  #
  # mode = :full  → tạo cả TestStep / TestStepContent / TestRun / TestResult / Bug + comment + evidence
  # mode = :light → chỉ TestCase + Bug tối thiểu (không step/run/result)
  #
  # root_specs: mảng 200 phần tử { title:, redmine_id:, closed: } — closed=true là task đã đóng.
  class ProjectBuilder
    LIB = ContentLibrary
    TC_PER_LEAF = 12
    SUBTASKS_PER_PARENT = 5

    NO_SUB_CLOSED = 95
    SUB_CLOSED = 95
    SUB_OPEN = 5   # Nhóm C
    NO_SUB_OPEN = 5 # Nhóm D

    BUG_OPEN_STATUSES = %w[new fixing testing pending].freeze

    Leaf = Struct.new(:task, :feature, :has_bug, :is_open, keyword_init: true)

    def initialize(project:, mode:, users:, time_window:, root_specs:)
      @project = project
      @mode = mode
      @users = users.presence || [ User.first ].compact
      @tw = time_window
      @specs = root_specs
      @order = 0
      @leaves = []
      @stats = Hash.new(0)
    end

    def build!
      validate_specs!
      # Structural layout (subtask & bug placement) unchanged; statuses come from
      # each spec (150 closed + 10 each of new/pending/in progress/resolved/waiting release).
      build_group(@specs[0...NO_SUB_CLOSED], with_subtask: false, bug_count: 10)
      build_group(@specs[NO_SUB_CLOSED...(NO_SUB_CLOSED + SUB_CLOSED)], with_subtask: true, bug_count: 10)
      build_group(@specs[190...195], with_subtask: true, bug_count: 5)
      build_group(@specs[195...200], with_subtask: false, bug_count: 0)
      build_test_cases
      build_full_details if @mode == :full
      build_bugs
      refresh_counters
      @stats
    end

    private

    def validate_specs!
      return if @specs.size == 200

      raise "Project #{@project.name}: cần 200 root spec, đang có #{@specs.size}"
    end

    # ---------- Tasks ----------

    def build_group(specs, with_subtask:, bug_count:)
      specs.each_with_index do |spec, i|
        root = create_root(spec)
        if with_subtask
          build_subtasks(root, feature_for(spec), bug_on_first: i < bug_count)
        else
          @leaves << Leaf.new(task: root, feature: feature_for(spec),
                              has_bug: i < bug_count, is_open: open_status?(root.status))
        end
      end
    end

    def build_subtasks(parent, feature, bug_on_first:)
      status = parent.status
      pct = percent_for(status)
      SUBTASKS_PER_PARENT.times do |k|
        sub = @project.tasks.create!(
          parent: parent,
          title: "#{parent.title} — Subtask #{k + 1}",
          status: status,
          description: "Subtask #{k + 1} thuộc task ##{parent.id} (#{feature}).",
          assignee: pick_user(parent.id + k),
          percent_done: pct,
          test_phase: test_phase_for(status),
          testing_type: parent.testing_type,
          created_at: parent.created_at + (k + 1) * 60,
          updated_at: parent.created_at + (k + 1) * 60
        )
        @leaves << Leaf.new(task: sub, feature: feature,
                            has_bug: bug_on_first && k.zero?, is_open: open_status?(status))
      end
    end

    # Root task with the full set of management fields (Title, Description, Issue
    # Link, Status, Estimated/Spent, Assignee, %, Test Phase, dates, Testing Type, KPI).
    def create_root(spec)
      order = next_order
      status = sanitize_status(spec[:status])
      created = created_at_for(closed: status == 'closed', index: order, total: 200)
      est = 8 + (order % 6) * 4
      pct = percent_for(status)
      spent = pct >= 100 ? est : (est * pct / 100.0).round(1)

      @project.tasks.create!(
        redmine_id: spec[:redmine_id],
        title: spec[:title],
        status: status,
        description: root_description(spec, status),
        issue_link: redmine_issue_link(spec[:redmine_id]),
        assignee: pick_user(order),
        estimated_time: est,
        spent_time: spent,
        percent_done: pct,
        test_phase: test_phase_for(status),
        testing_type: Task::TESTING_TYPES[order % Task::TESTING_TYPES.size],
        kpi_targets: kpi_targets,
        start_date: created.to_date,
        due_date: created.to_date + 14,
        created_at: created,
        updated_at: created
      )
    end

    # closed: trải từ tw[:closed_from] → tw[:closed_to]; non-closed: tw[:open_from] → tw[:open_to].
    # Đảm bảo mọi task chưa đóng có created_at > mọi task đã đóng.
    def created_at_for(closed:, index:, total:)
      from, to = closed ? [ @tw[:closed_from], @tw[:closed_to] ] : [ @tw[:open_from], @tw[:open_to] ]
      span = to - from
      from + (span * index / [ total - 1, 1 ].max)
    end

    # ---------- Status-derived attributes ----------

    def next_order
      o = @order
      @order += 1
      o
    end

    def open_status?(status)
      status.to_s != 'closed'
    end

    def sanitize_status(status)
      s = status.to_s.strip
      Task::STATUSES.include?(s) ? s : 'new'
    end

    # In Progress / Resolved / Waiting Release / Closed = 100%; Pending = 40%; New = 0%.
    def percent_for(status)
      case status
      when 'closed', 'in progress', 'resolved', 'waiting release' then 100
      when 'pending' then 40
      else 0
      end
    end

    def test_phase_for(status)
      case status
      when 'closed', 'resolved' then 'completed'
      when 'waiting release' then 'reporting'
      when 'in progress' then 'executing'
      when 'pending' then 'creating_testcases'
      else 'not_started'
      end
    end

    def kpi_targets
      @kpi_targets ||= Task::KPIS.transform_values { |meta| meta[:default_target] }
    end

    def redmine_issue_link(redmine_id)
      return nil if redmine_id.blank?

      # Browser-facing URL (see ProjectsHelper#redmine_base_url).
      base = ENV['REDMINE_PUBLIC_URL'].presence ||
             ENV.fetch('REDMINE_BASE_URL', 'http://localhost:3001').sub('redmine:3000', 'localhost:3001')
      "#{base}/issues/#{redmine_id}"
    end

    def root_description(spec, status)
      feature = feature_for(spec)
      origin = spec[:redmine_id] ? "Đồng bộ từ Redmine issue ##{spec[:redmine_id]}." : 'Task nội bộ Tooltest.'
      [
        origin,
        "Chức năng kiểm thử: #{feature}.",
        "Mục tiêu: đảm bảo \"#{feature}\" hoạt động đúng đặc tả trên các thiết bị/trình duyệt hỗ trợ.",
        "Trạng thái hiện tại: #{status}."
      ].join("\n")
    end

    # ---------- Test cases ----------

    def build_test_cases
      @leaves.each do |leaf|
        rows = Array.new(TC_PER_LEAF) do |i|
          sc = LIB::TC_SCENARIOS[i]
          base_time = leaf.task.created_at
          {
            task_id: leaf.task.id,
            created_by_id: pick_user(leaf.task.id + i).id,
            title: "TC#{i + 1}: #{leaf.feature} — #{sc[:suffix]}",
            description: "Kịch bản kiểm thử cho \"#{leaf.feature}\" (#{sc[:suffix]}). #{sc[:note]}",
            test_type: sc[:test_type],
            target: sc[:target],
            note: sc[:note],
            position: i + 1,
            created_at: base_time,
            updated_at: base_time
          }
        end
        TestCase.insert_all!(rows)
        @stats[:test_cases] += rows.size
      end
    end

    # ---------- Full details: steps, contents, runs, results ----------

    def build_full_details
      @leaves.each do |leaf|
        tc_ids = TestCase.where(task_id: leaf.task.id).order(:position).pluck(:id, :position)
        pos_by_id = tc_ids.to_h
        ids = tc_ids.map(&:first)

        build_steps_and_contents(leaf, ids, pos_by_id)
        run = build_test_run(leaf)
        build_test_results(leaf, ids, pos_by_id, run)
      end
    end

    def build_steps_and_contents(leaf, case_ids, pos_by_id)
      base_time = leaf.task.created_at
      step_rows = case_ids.flat_map do |cid|
        sc = LIB::TC_SCENARIOS[pos_by_id[cid] - 1]
        sc[:steps].each_with_index.map do |st, idx|
          { case_id: cid, step_number: idx + 1, description: LIB.fill(st[:action], leaf.feature),
            display_order: idx, created_at: base_time, updated_at: base_time }
        end
      end
      TestStep.insert_all!(step_rows)
      @stats[:test_steps] += step_rows.size
      build_step_contents(leaf, case_ids, pos_by_id, base_time)
    end

    def build_step_contents(leaf, case_ids, pos_by_id, base_time)
      steps = TestStep.where(case_id: case_ids).order(:case_id, :step_number).pluck(:id, :case_id, :step_number)
      content_rows = steps.flat_map do |sid, cid, num|
        st = LIB::TC_SCENARIOS[pos_by_id[cid] - 1][:steps][num - 1]
        [ content_row(sid, 'action', LIB.fill(st[:action], leaf.feature), 0, base_time),
          content_row(sid, 'expectation', LIB.fill(st[:expectation], leaf.feature), 1, base_time) ]
      end
      TestStepContent.insert_all!(content_rows)
      @stats[:test_step_contents] += content_rows.size
    end

    def content_row(step_id, category, value, order, time)
      {
        step_id: step_id,
        content_type: 'text',
        content_value: value,
        is_expected: category == 'expectation',
        content_category: category,
        display_order: order,
        created_at: time,
        updated_at: time
      }
    end

    def build_test_run(leaf)
      completed = leaf.task.created_at + 3600
      TestRun.create!(
        task: leaf.task,
        executed_by: pick_user(leaf.task.id),
        name: "Test Run — #{leaf.feature}",
        description: "Phiên kiểm thử cho task ##{leaf.task.id}.",
        status: leaf.is_open ? 'running' : 'completed',
        started_at: leaf.task.created_at,
        completed_at: leaf.is_open ? nil : completed,
        executed_at: leaf.task.created_at,
        created_at: leaf.task.created_at,
        updated_at: completed
      )
    end

    def build_test_results(leaf, case_ids, pos_by_id, run)
      base_time = leaf.task.created_at
      rows = case_ids.map do |cid|
        pos = pos_by_id[cid]
        # Task có bug: cho TC#1 fail để gắn bug; còn lại chủ yếu pass, rải vài not_run.
        status = if leaf.has_bug && pos == 1
          'fail'
        elsif (pos % 6).zero?
          'not_run'
        else
          'pass'
        end
        {
          run_id: run.id,
          case_id: cid,
          status: status,
          device: LIB::DEVICES[pos % LIB::DEVICES.size],
          executed_by_id: pick_user(cid).id,
          executed_at: base_time,
          created_at: base_time,
          updated_at: base_time
        }
      end
      TestResult.insert_all!(rows)
      @stats[:test_results] += rows.size
    end

    # ---------- Bugs ----------

    def build_bugs
      @leaves.select(&:has_bug).each_with_index do |leaf, i|
        tmpl = LIB::BUG_TEMPLATES[i % LIB::BUG_TEMPLATES.size]
        status = leaf.is_open ? BUG_OPEN_STATUSES[i % BUG_OPEN_STATUSES.size] : 'done'
        result_id = @mode == :full ? failing_result_id(leaf) : nil

        bug = Bug.create!(
          task: leaf.task,
          test_result_id: result_id,
          dev: pick_user(leaf.task.id + 1),
          tester: pick_user(leaf.task.id + 2),
          title: LIB.fill(tmpl[:title], leaf.feature),
          description: LIB.fill(tmpl[:description], leaf.feature),
          content: LIB.fill(tmpl[:description], leaf.feature),
          category: tmpl[:category],
          priority: tmpl[:priority],
          status: status,
          application: tmpl[:application],
          bug_type: tmpl[:bug_type],
          created_at: leaf.task.created_at + 1800,
          updated_at: leaf.task.created_at + 1800
        )
        @stats[:bugs] += 1
        build_bug_children(bug, leaf)
      end
    end

    def build_bug_children(bug, leaf)
      comment_count = leaf.is_open ? 2 : LIB::BUG_COMMENTS.size
      LIB::BUG_COMMENTS.first(comment_count).each_with_index do |text, i|
        BugComment.create!(
          bug: bug,
          user: pick_user(bug.id + i),
          content: text,
          created_at: bug.created_at + (i + 1) * 600,
          updated_at: bug.created_at + (i + 1) * 600
        )
        @stats[:bug_comments] += 1
      end

      BugEvidence.create!(
        bug: bug,
        content_type: 'image',
        content_value: "https://evidence.example.com/bugs/#{bug.id}/screenshot.png"
      )
      @stats[:bug_evidences] += 1
    end

    def failing_result_id(leaf)
      TestResult.joins(:test_case)
                .where(test_cases: { task_id: leaf.task.id }, status: 'fail')
                .order(:id).limit(1).pick(:id)
    end

    # ---------- Helpers ----------

    def refresh_counters
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        UPDATE tasks t
        SET number_of_test_cases = (
          SELECT COUNT(*) FROM test_cases tc
          WHERE tc.task_id = t.id AND tc.deleted_at IS NULL
        )
        WHERE t.project_id = #{@project.id.to_i}
      SQL

      # Aggregate bug counts (subtree) onto each root task so the app and Redmine
      # show equivalent figures (pushed to Redmine by script/sync_redmine_indices.rb).
      @project.tasks.where(parent_id: nil).find_each do |root|
        ids = [ root.id ] + root.subtasks.pluck(:id)
        scope = Bug.where(task_id: ids)
        root.update_columns(
          stg_bugs_vn: scope.where(category: 'stg_vn').count,
          stg_bugs_jp: scope.where(category: 'stg_jp').count,
          prod_bugs: scope.where(category: 'prod').count
        )
      end
    end

    def pick_user(seed)
      @users[seed % @users.size]
    end

    def feature_for(spec)
      spec[:feature].presence || feature_of(spec[:title])
    end

    # Trích "tên chức năng" từ title (loại tiền tố Redmine "4. Testing - #123 【Grp】").
    def feature_of(title)
      base = title.to_s.sub(/\A\d+\.\s*Testing\s*-\s*#\d+\s*/, '').strip
      base.sub(/\A【[^】]*】\s*/, '').sub(/\A\[[^\]]*\]\s*/, '').strip
    end
  end
end
