require "json"
require "uri"

class WeatherApi
  BASE_URL = "https://api.weatherapi.com/v1"
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 8
  NOT_FOUND_CODE = 1006

  def initialize(http: Http::Client.new(open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT))
    @http = http
  end

  def fetch(query:, days: nil)
    response = @http.get(request_uri(query:, days:))

    case response.status
    when 200
      parse_json(response.body)
    when 429
      raise Providers::Unavailable.new("Weather provider rate limit exceeded", http_status: 429)
    when 500..599
      raise Providers::Unavailable.new("Weather provider is unavailable", http_status: response.status)
    else
      interpret_failure(response)
    end
  end

  private

  def request_uri(query:, days:)
    endpoint = days.to_i.positive? ? "forecast" : "current"
    uri = URI.parse("#{BASE_URL}/#{endpoint}.json")
    params = { key: api_key, q: query }
    params[:days] = days.to_i if days.to_i.positive?
    uri.query = URI.encode_www_form(params)
    uri
  end

  def api_key
    ENV.fetch("WEATHER_API_KEY")
  rescue KeyError
    raise Providers::Unavailable.new("Weather provider is not configured")
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    raise Providers::Unavailable.new("Weather provider returned an unreadable response")
  end

  def interpret_failure(response)
    error = error_payload(response.body)
    if error[:code].to_i == NOT_FOUND_CODE
      raise Providers::NotFound.new("No location matched that address", http_status: response.status)
    end

    raise Providers::Unavailable.new("Weather provider rejected the request", http_status: response.status)
  end

  def error_payload(body)
    json = JSON.parse(body)
    error = json.fetch("error", {})
    { code: error["code"], message: error["message"] }
  rescue JSON::ParserError
    {}
  end
end
