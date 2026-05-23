module BugImport
  class AttributeMapper
    def map(parsed_row)
      dev_name = parsed_row[:dev]
      tester_name = parsed_row[:tester]

      {
        content: parsed_row[:content],
        application: normalize_application(parsed_row[:application]),
        category: normalize_category(parsed_row[:category]),
        priority: normalize_priority(parsed_row[:priority]),
        status: normalize_status(parsed_row[:status]),
        bug_type: normalize_bug_type(parsed_row[:bug_type]),
        image_video_url: parsed_row[:media],
        dev_id: find_user(dev_name)&.id,
        tester_id: find_user(tester_name)&.id,
        dev_name_raw: dev_name,
        tester_name_raw: tester_name
      }
    end

    private

    def find_user(name)
      return nil if name.blank?

      User.where('name LIKE ?', "%#{name}%").first
    end

    def normalize_application(app)
      return 'sp_pc' if app.blank?

      normalized = app.downcase.gsub(' ', '')
      return 'app' if normalized.match?(/app/)
      return 'sp' if normalized.match?(/sp/) && !normalized.match?(/sp\+pc/)
      return 'pc' if normalized.match?(/pc/) && !normalized.match?(/sp\+pc/)

      'sp_pc'
    end

    def normalize_category(cat)
      return 'stg_vn' if cat.blank?

      normalized = cat.downcase
      return 'stg_jp' if normalized.match?(/stg.*jp/)
      return 'prod' if normalized.match?(/prod/)

      'stg_vn'
    end

    def normalize_priority(pri)
      return 'normal' if pri.blank?

      case pri.downcase
      when /high/, /cao/ then 'high'
      when /low/, /thấp/ then 'low'
      else 'normal'
      end
    end

    def normalize_status(stat)
      return 'new' if stat.blank?

      case stat.downcase
      when /done/, /completed/, /ok/ then 'done'
      when /fixing/, /in progress/ then 'fixing'
      when /testing/ then 'testing'
      when /pending/, /chờ/ then 'pending'
      else 'new'
      end
    end

    def normalize_bug_type(bt)
      return 'new_bug' if bt.blank?

      case bt.downcase
      when /new/, /mới/ then 'new_bug'
      when /old/, /cũ/ then 'old_bug'
      when /improve/, /cải tiến/ then 'improve'
      else 'new_bug'
      end
    end
  end
end
