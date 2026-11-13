class Forecast < Data.define(
  :location_name,
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
  :day_offset,
  :daytime
)
  def self.from_api_response(response, day_offset: 0)
    location = response.fetch("location", {})
    offset = day_offset.to_i
    daily = offset.positive? ? forecast_day(response, offset) : nil

    if daily
      from_daily(location, daily[:entry], daily[:index])
    else
      from_current(location, response.fetch("current", {}))
    end
  end

  def location_label
    [ location_name, region, country ].compact.map { |part| part.to_s.strip }.reject(&:empty?).join(", ")
  end

  def daytime?
    daytime
  end

  def daylight_label
    daytime ? "Daytime" : "Nighttime"
  end

  def day_offset_label
    case day_offset.to_i
    when 0 then "Today"
    when 1 then "Tomorrow"
    else "In #{day_offset.to_i} days"
    end
  end

  def as_json(*)
    {
      location_label: location_label,
      temperature_c: temperature_c,
      temperature_f: temperature_f,
      min_temperature_c: min_temperature_c,
      min_temperature_f: min_temperature_f,
      max_temperature_c: max_temperature_c,
      max_temperature_f: max_temperature_f,
      humidity: humidity,
      wind_kph: wind_kph,
      wind_direction: wind_direction,
      precip_inches: precip_inches,
      visibility_miles: visibility_miles,
      uv_index: uv_index,
      last_updated: last_updated,
      condition_text: condition_text,
      condition_icon_url: condition_icon_url,
      forecast_date: forecast_date,
      day_offset: day_offset.to_i,
      day_offset_label: day_offset_label,
      local_time: local_time
    }
  end

  class << self
    private

    def forecast_day(response, offset)
      days = Array(response.dig("forecast", "forecastday"))
      return if days.empty?

      index = [ [ offset, days.length - 1 ].min, 0 ].max
      { entry: days[index], index: index }
    end

    def from_daily(location, daily, offset)
      day = daily.fetch("day", {}) || {}
      condition = day.fetch("condition", {}) || {}

      from_parts(
        location: location,
        current: {
          "temp_c" => day["avgtemp_c"],
          "temp_f" => day["avgtemp_f"],
          "min_temp_c" => day["mintemp_c"],
          "min_temp_f" => day["mintemp_f"],
          "max_temp_c" => day["maxtemp_c"],
          "max_temp_f" => day["maxtemp_f"],
          "humidity" => day["avghumidity"],
          "wind_kph" => day["maxwind_kph"],
          "wind_dir" => nil,
          "precip_in" => day["totalprecip_in"],
          "vis_miles" => day["avgvis_miles"],
          "uv" => day["uv"],
          "last_updated" => daily["date"],
          "condition" => condition
        },
        day_offset: offset,
        forecast_date: daily["date"],
        daytime: nil
      )
    end

    def from_current(location, current)
      from_parts(
        location: location,
        current: current,
        day_offset: 0,
        forecast_date: nil,
        daytime: daytime_flag(current)
      )
    end

    def from_parts(location:, current:, day_offset:, forecast_date:, daytime:)
      condition = current.fetch("condition", {}) || {}

      new(
        location_name: location["name"],
        region: location["region"],
        country: location["country"],
        latitude: location["lat"],
        longitude: location["lon"],
        time_zone: location["tz_id"],
        local_time: location["localtime"],
        temperature_c: current["temp_c"],
        temperature_f: current["temp_f"],
        humidity: current["humidity"],
        wind_kph: current["wind_kph"],
        wind_direction: current["wind_dir"],
        precip_inches: current["precip_in"],
        visibility_miles: current["vis_miles"],
        uv_index: current["uv"],
        last_updated: current["last_updated"],
        condition_text: condition["text"],
        condition_icon_url: normalize_icon_url(condition["icon"]),
        condition_code: condition["code"],
        min_temperature_c: current["min_temp_c"],
        min_temperature_f: current["min_temp_f"],
        max_temperature_c: current["max_temp_c"],
        max_temperature_f: current["max_temp_f"],
        forecast_date: forecast_date,
        day_offset: day_offset,
        daytime: daytime
      )
    end

    def daytime_flag(current)
      return if !current.key?("is_day") || current["is_day"].nil?

      current["is_day"].to_i == 1
    end

    def normalize_icon_url(icon)
      return if icon.blank?

      icon.start_with?("http") ? icon : "https:#{icon}"
    end
  end
end
