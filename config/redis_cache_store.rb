module RedisCacheStoreConfig
  module_function

  def options
    {
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
      namespace: "ruby-weather",
      reconnect_attempts: 1,
      error_handler: lambda { |method:, returning:, exception:|
        fallback = returning.nil? ? "none" : returning.class.name
        Rails.logger.error("Redis cache #{method} failed: #{exception.class}: #{exception.message} (fallback #{fallback})")
        raise exception
      }
    }
  end
end
