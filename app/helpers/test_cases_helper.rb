module TestCasesHelper
  def format_device_name(device_name)
    return '' if device_name.blank?

    formatted = device_name.to_s.split(/\s+/).first.to_s.upcase
    formatted == 'PRODUCTION' ? 'PROD' : formatted
  end
end
