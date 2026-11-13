require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
ENV["WEATHER_API_KEY"] ||= "test-key"

require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort.each { |file| require file }

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include ActiveSupport::Testing::TimeHelpers

  config.before do
    Rails.cache.clear
  end
end
