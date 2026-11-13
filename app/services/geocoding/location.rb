module Geocoding
  Location = Data.define(
    :name,
    :latitude,
    :longitude,
    :postal_code,
    :country,
    :country_code,
    :region
  ) do
    COORDINATE_PRECISION = 2

    def cache_identity
      code = postal_code.to_s.strip
      return rounded_lat_lon if code.empty?

      country = country_code.to_s.strip.downcase
      country.empty? ? "postal:#{normalize_code(code)}" : "postal:#{country}:#{normalize_code(code)}"
    end

    def coordinate_query
      format("%.4f,%.4f", latitude.to_f, longitude.to_f)
    end

    def as_json(*)
      {
        name: name,
        latitude: latitude,
        longitude: longitude,
        postal_code: postal_code,
        country: country,
        country_code: country_code,
        region: region,
        cache_key: cache_identity
      }
    end

    private

    def rounded_lat_lon
      format(
        "lat_lon:%.2f:%.2f",
        latitude.to_f.round(COORDINATE_PRECISION),
        longitude.to_f.round(COORDINATE_PRECISION)
      )
    end

    def normalize_code(code)
      code.downcase.gsub(/\s+/, "")
    end
  end
end
