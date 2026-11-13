require "rails_helper"

RSpec.describe "cache store configuration" do
  it "keeps the shared Redis store out of the test process and the memory store out of production" do
    application = Rails.root.join("config/application.rb").read
    production = Rails.root.join("config/environments/production.rb").read
    development = Rails.root.join("config/environments/development.rb").read
    test_env = Rails.root.join("config/environments/test.rb").read

    expect(application).not_to include("memory_store")
    expect(application).not_to include("cache_store")
    expect(production).to include("redis_cache_store")
    expect(production).not_to include("memory_store")
    expect(development).to include("redis_cache_store")
    expect(development).not_to include("memory_store")
    expect(test_env).to include("memory_store")
    expect(Rails.cache).to be_a(ActiveSupport::Cache::MemoryStore)
  end
end
