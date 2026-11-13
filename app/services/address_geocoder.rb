class AddressGeocoder
  BASE_URL = "https://nominatim.openstreetmap.org/search"
  USER_AGENT = "RubyWeather/1.0 (forecast lookup)"
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 5
  CACHE_TTL = 30.minutes
  RACE_TTL = 10.seconds
  GATE_KEY = "geocode:nominatim:slot"

  def self.geocode(address)
    new.geocode(address)
  end

  def initialize(
    http: Http::Client.new(open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT),
    cache: Rails.cache,
    min_interval: ENV.fetch("GEOCODER_MIN_INTERVAL", "1").to_f
  )
    @http = http
    @cache = cache
    @min_interval = min_interval
  end

  def geocode(address)
    sanitized = sanitize(address)
    @cache.fetch(cache_key(sanitized), expires_in: CACHE_TTL, race_condition_ttl: RACE_TTL) do
      with_provider_slot { fetch_location(sanitized) }
    end
  end

  private

  def sanitize(address)
    address.to_s.gsub(/\s+/, " ").strip
  end

  def cache_key(address)
    "geocode:v1:#{address.downcase}"
  end

  def with_provider_slot
    return yield if @min_interval <= 0

    acquired = @cache.write(GATE_KEY, true, unless_exist: true, expires_in: @min_interval)
    unless acquired
      raise Providers::Unavailable.new("Geocoding provider rate limit exceeded", http_status: 429)
    end

    yield
  end

  def fetch_location(address)
    response = @http.get(search_uri(address), headers: request_headers)

    case response.status
    when 200
      parse_location(response.body)
    when 429
      raise Providers::Unavailable.new("Geocoding provider rate limit exceeded", http_status: 429)
    when 500..599
      raise Providers::Unavailable.new("Geocoding provider is unavailable", http_status: response.status)
    when 404
      raise Providers::NotFound.new("No location matched that address", http_status: response.status)
    else
      raise Providers::Unavailable.new("Geocoding provider rejected the query", http_status: response.status)
    end
  end

  def search_uri(address)
    uri = URI.parse(BASE_URL)
    uri.query = URI.encode_www_form(q: address, format: "jsonv2", addressdetails: 1, limit: 1)
    uri
  end

  def request_headers
    {
      "User-Agent" => USER_AGENT,
      "Accept" => "application/json",
      "Accept-Language" => "en"
    }
  end

  def parse_location(body)
    payload = JSON.parse(body)
    hit = location_hit(payload)
    address = hit.fetch("address", {}) || {}

    Geocoding::Location.new(
      name: location_name(hit),
      latitude: parse_coordinate(hit["lat"]),
      longitude: parse_coordinate(hit["lon"]),
      postal_code: presence(address["postcode"]),
      country: presence(address["country"]),
      country_code: presence(address["country_code"]),
      region: presence(address["state"] || address["region"] || address["county"])
    )
  rescue JSON::ParserError
    raise Providers::Unavailable.new("Geocoding provider returned an unreadable response")
  end

  def location_hit(payload)
    hit = payload.is_a?(Array) ? payload.first : nil
    if hit.is_a?(Hash) && hit["lat"].present? && hit["lon"].present?
      return hit
    end

    if payload.is_a?(Hash) && payload["error"].present?
      raise Providers::Unavailable.new("Geocoding provider rejected the query")
    end

    raise Providers::NotFound.new("No location matched that address")
  end

  def location_name(hit)
    name = hit["name"].to_s.strip
    return name if name.present?

    hit["display_name"].to_s.split(",").first.to_s.strip
  end

  def parse_coordinate(value)
    Float(value)
  rescue ArgumentError, TypeError
    raise Providers::Unavailable.new("Geocoding provider returned coordinates we couldn't read")
  end

  def presence(value)
    text = value.to_s.strip
    text.empty? ? nil : text
  end
end
