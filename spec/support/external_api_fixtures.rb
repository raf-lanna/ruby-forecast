module ExternalApiFixtures
  def nominatim_result(name:, lat:, lon:, postcode: nil, country: "France", country_code: "fr", region: "Ile-de-France")
    address = {
      "country" => country,
      "country_code" => country_code,
      "state" => region
    }
    address["postcode"] = postcode if postcode

    [
      {
        "name" => name,
        "lat" => lat.to_s,
        "lon" => lon.to_s,
        "display_name" => "#{name}, #{region}, #{country}",
        "address" => address
      }
    ].to_json
  end

  def weather_current(name:, temp_c: 18.2, temp_f: 64.8)
    {
      "location" => {
        "name" => name,
        "region" => "Ile-de-France",
        "country" => "France",
        "lat" => 48.86,
        "lon" => 2.35,
        "tz_id" => "Europe/Paris",
        "localtime" => "2026-11-12 21:00"
      },
      "current" => {
        "temp_c" => temp_c,
        "temp_f" => temp_f,
        "humidity" => 55,
        "wind_kph" => 12.0,
        "wind_dir" => "SW",
        "precip_in" => 0.0,
        "vis_miles" => 9.0,
        "uv" => 3.0,
        "last_updated" => "2026-11-12 21:00",
        "is_day" => 1,
        "condition" => {
          "text" => "Clear",
          "icon" => "//cdn.weatherapi.com/weather/64x64/day/113.png",
          "code" => 1000
        }
      }
    }.to_json
  end

  def weather_forecast(name:, temp_f:)
    days = Array.new(3) do |index|
      {
        "date" => format("2026-11-%02d", 12 + index),
        "day" => {
          "avgtemp_c" => 10 + index,
          "avgtemp_f" => index == 2 ? temp_f : 50,
          "mintemp_f" => 40,
          "maxtemp_f" => 70,
          "avghumidity" => 40,
          "maxwind_kph" => 10,
          "totalprecip_in" => 0.1,
          "avgvis_miles" => 8,
          "uv" => 2,
          "condition" => {
            "text" => "Cloudy",
            "icon" => "//cdn.weatherapi.com/weather/64x64/day/119.png",
            "code" => 1003
          }
        }
      }
    end

    {
      "location" => {
        "name" => name,
        "region" => "Ile-de-France",
        "country" => "France"
      },
      "forecast" => { "forecastday" => days }
    }.to_json
  end
end

RSpec.configure do |config|
  config.include ExternalApiFixtures
end
