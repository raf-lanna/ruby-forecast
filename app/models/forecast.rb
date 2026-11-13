class Forecast
  attr_reader :location_name,
              :region,
              :country,
              :latitude,
              :longitude,
              :time_zone,
              :local_time,
              :temperature_c,
              :temperature_f,
              :humidity,
              :wind_kph,
              :wind_direction,
              :precip_inches,
              :visibility_miles,
              :uv_index,
              :last_updated,
              :condition_text,
              :condition_icon_url,
              :condition_code,
              :min_temperature_c,
              :min_temperature_f,
              :max_temperature_c,
              :max_temperature_f,
              :forecast_date,
              :day_offset_label

  def self.from_api_response(response, day_offset: 0)
    location = response.fetch("location", {})

    if day_offset.to_i.positive?
      forecast_days = Array(response.dig("forecast", "forecastday"))
      index = [ [ day_offset.to_i, forecast_days.length - 1 ].min, 0 ].max
      daily = forecast_days[index]

      if daily
        day = daily.fetch("day", {}) || {}
        condition = day.fetch("condition", {}) || {}

        pseudo_current = {
          "temp_c"       => day["avgtemp_c"],
          "temp_f"       => day["avgtemp_f"],
          "min_temp_c"   => day["mintemp_c"],
          "min_temp_f"   => day["mintemp_f"],
          "max_temp_c"   => day["maxtemp_c"],
          "max_temp_f"   => day["maxtemp_f"],
          "humidity"     => day["avghumidity"],
          "wind_kph"     => day["maxwind_kph"],
          "wind_dir"     => nil,
          "precip_in"    => day["totalprecip_in"],
          "vis_miles"    => day["avgvis_miles"],
          "uv"           => day["uv"],
          "last_updated" => daily["date"],
          "is_day"       => nil,
          "condition"    => condition
        }

        return new(location: location,
                   current: pseudo_current,
                   day_offset: index,
                   forecast_date: daily["date"])
      end
    end

    current = response.fetch("current", {})
    new(location: location, current: current, day_offset: 0)
  end

  def initialize(location:, current:, day_offset:, forecast_date: nil)
    condition = current.fetch("condition", {}) || {}

    @location_name = location["name"]
    @region        = location["region"]
    @country       = location["country"]
    @latitude      = location["lat"]
    @longitude     = location["lon"]
    @time_zone     = location["tz_id"]
    @local_time    = location["localtime"]

    @temperature_c     = current["temp_c"]
    @temperature_f     = current["temp_f"]
    @min_temperature_c = current["min_temp_c"]
    @min_temperature_f = current["min_temp_f"]
    @max_temperature_c = current["max_temp_c"]
    @max_temperature_f = current["max_temp_f"]
    @humidity          = current["humidity"]
    @wind_kph          = current["wind_kph"]
    @wind_direction    = current["wind_dir"]
    @precip_inches     = current["precip_in"]
    @visibility_miles  = current["vis_miles"]
    @uv_index          = current["uv"]
    @last_updated      = current["last_updated"]

    raw_is_day = current.key?("is_day") ? current["is_day"] : nil
    @is_daytime = raw_is_day.nil? ? nil : raw_is_day.to_i == 1

    @condition_text = condition["text"]
    @condition_code = condition["code"]
    @condition_icon_url = normalize_icon_url(condition["icon"])

    @forecast_date = forecast_date
    @day_offset_label = build_day_offset_label(day_offset)
  end

  def location_label
    [ location_name, region, country ].compact.reject(&:blank?).join(", ")
  end

  def daytime?
    @is_daytime
  end

  def daylight_label
    daytime? ? "Daytime" : "Nighttime"
  end

  private

  def build_day_offset_label(offset)
    return "Today" if offset.to_i.zero?
    return "Tomorrow" if offset == 1

    "In #{offset} days"
  end

  def normalize_icon_url(icon)
    return if icon.blank?

    icon.start_with?("http") ? icon : "https:#{icon}"
  end
end
