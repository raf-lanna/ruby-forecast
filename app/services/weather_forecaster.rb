class WeatherForecaster
  def self.forecast(location:, days:)
    new.forecast(location:, days:)
  end

  def initialize(client: WeatherApi.new)
    @client = client
  end

  def forecast(location:, days:)
    offset = Integer(days)
    payload = @client.fetch(query: location.coordinate_query, days: api_days(offset))
    Forecast.from_api_response(payload, day_offset: offset)
  end

  private

  def api_days(offset)
    return if offset.zero?

    offset + 1
  end
end
