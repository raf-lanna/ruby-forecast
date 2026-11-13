module Forecasts
  class Lookup
    CACHE_TTL = 30.minutes
    RACE_TTL = 10.seconds

    Result = Data.define(:forecast, :location, :cache_hit, :address) do
      def as_json(*)
        {
          address: address,
          cache_hit: cache_hit,
          location: location.as_json,
          forecast: forecast.as_json
        }
      end
    end

    def initialize(address, days: 0, geocoder: AddressGeocoder, forecaster: WeatherForecaster, cache: Rails.cache)
      @address = address
      @days = days.to_i
      @geocoder = geocoder
      @forecaster = forecaster
      @cache = cache
    end

    def call
      location = @geocoder.geocode(@address)
      cache_hit = true
      forecast = @cache.fetch(forecast_key(location), expires_in: CACHE_TTL, race_condition_ttl: RACE_TTL) do
        cache_hit = false
        @forecaster.forecast(location:, days: @days)
      end

      Result.new(forecast:, location:, cache_hit:, address: @address)
    rescue *cache_failures => e
      raise Providers::Unavailable.new("Forecast cache is unavailable (#{e.class})")
    end

    private

    def forecast_key(location)
      "forecast:v1:#{location.cache_identity}:d#{@days}"
    end

    def cache_failures
      failures = [ ActiveSupport::Cache::DeserializationError ]
      failures << Redis::BaseError if defined?(Redis::BaseError)
      failures
    end
  end
end
