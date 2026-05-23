module TestCasesHelper
  def format_device_name(device_name)
    return '' if device_name.blank?

    # Extract the first word and capitalize it
    # Handles "CHROME V131.0.6778.109", "FIREFOX V133.0.3", "SAFARI V16.5 (18615.2.9.11.4)", "IOS", "APP"
    formatted = device_name.to_s.split(/\s+/).first.to_s.upcase
    formatted == 'PRODUCTION' ? 'PROD' : formatted
  end
end
