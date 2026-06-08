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

    OPEN_STATUS = 'in progress'
    CLOSED_STATUS = 'closed'
    BUG_OPEN_STATUSES = %w[new fixing testing pending].freeze

    Leaf = Struct.new(:task, :feature, :has_bug, :is_open, keyword_init: true)

    def initialize(project:, mode:, users:, time_window:, root_specs:)
      @project = project
      @mode = mode
      @users = users
      @tw = time_window
      @closed_specs = root_specs.select { |s| s[:closed] }
      @open_specs = root_specs.reject { |s| s[:closed] }
      @leaves = []
      @stats = Hash.new(0)
    end

    def build!
      validate_specs!
      build_closed_no_subtask
      build_closed_with_subtask
      build_open_with_subtask   # Nhóm C
      build_open_no_subtask     # Nhóm D
      build_test_cases
      build_full_details if @mode == :full
      build_bugs
      refresh_counters
      @stats
    end

    private

    def validate_specs!
      return if @closed_specs.size == 190 && @open_specs.size == 10

      raise "Project #{@project.name}: cần 190 closed + 10 open, đang có " \
            "#{@closed_specs.size} closed / #{@open_specs.size} open"
    end

    # ---------- Tasks ----------

    def build_closed_no_subtask
      specs = @closed_specs[0...NO_SUB_CLOSED]
      specs.each_with_index do |spec, i|
        task = create_root(spec, closed: true, order_index: i, order_total: 190)
        # Nhóm A: 10 task đầu nhánh này có bug
        @leaves << Leaf.new(task: task, feature: feature_for(spec), has_bug: i < 10, is_open: false)
      end
    end

    def build_closed_with_subtask
      specs = @closed_specs[NO_SUB_CLOSED, SUB_CLOSED]
      specs.each_with_index do |spec, i|
        parent = create_root(spec, closed: true, order_index: NO_SUB_CLOSED + i, order_total: 190)
        # Nhóm A: 10 task đầu nhánh này có bug (bug gắn vào subtask đầu tiên)
        parent_has_bug = i < 10
        build_subtasks(parent, feature_for(spec), closed: true, bug_on_first: parent_has_bug, is_open: false)
      end
    end

    def build_open_with_subtask
      @open_specs[0...SUB_OPEN].each_with_index do |spec, i|
        parent = create_root(spec, closed: false, order_index: i, order_total: 10)
        # Nhóm C: mỗi task open này có bug (gắn vào subtask đầu tiên)
        build_subtasks(parent, feature_for(spec), closed: false, bug_on_first: true, is_open: true)
      end
    end

    def build_open_no_subtask
      @open_specs[SUB_OPEN, NO_SUB_OPEN].each_with_index do |spec, i|
        task = create_root(spec, closed: false, order_index: SUB_OPEN + i, order_total: 10)
        # Nhóm D: không bug
        @leaves << Leaf.new(task: task, feature: feature_for(spec), has_bug: false, is_open: true)
      end
    end

    def build_subtasks(parent, feature, closed:, bug_on_first:, is_open:)
      SUBTASKS_PER_PARENT.times do |k|
        sub = @project.tasks.create!(
          parent: parent,
          title: "#{parent.title} — Subtask #{k + 1}",
          status: closed ? CLOSED_STATUS : OPEN_STATUS,
          description: "Subtask #{k + 1} thuộc task ##{parent.id} (#{feature}).",
          assignee: pick_user(parent.id + k),
          percent_done: closed ? 100 : (k * 15),
          created_at: parent.created_at + (k + 1) * 60,
          updated_at: parent.created_at + (k + 1) * 60
        )
        @leaves << Leaf.new(task: sub, feature: feature, has_bug: bug_on_first && k.zero?, is_open: is_open)
      end
    end

    def create_root(spec, closed:, order_index:, order_total:)
      created = created_at_for(closed: closed, index: order_index, total: order_total)
      desc = if spec[:redmine_id]
        "Đồng bộ từ Redmine issue ##{spec[:redmine_id]}."
      else
        'Task nội bộ của hệ thống Tooltest.'
      end
      @project.tasks.create!(
        redmine_id: spec[:redmine_id],
        title: spec[:title],
        status: closed ? CLOSED_STATUS : OPEN_STATUS,
        description: desc,
        assignee: pick_user(order_index),
        percent_done: closed ? 100 : (10 + order_index % 80),
        start_date: created.to_date,
        due_date: created.to_date + 14,
        created_at: created,
        updated_at: created
      )
    end

    # closed: trải từ tw[:closed_from] → tw[:closed_to]; open: tw[:open_from] → tw[:open_to].
    # Đảm bảo mọi open > mọi closed (hai cửa sổ không giao nhau).
    def created_at_for(closed:, index:, total:)
      from, to = closed ? [ @tw[:closed_from], @tw[:closed_to] ] : [ @tw[:open_from], @tw[:open_to] ]
      span = to - from
      from + (span * index / [ total - 1, 1 ].max)
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