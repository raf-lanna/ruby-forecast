require "rails_helper"

RSpec.describe WeatherForecaster do
  let(:location) do
    Geocoding::Location.new(
      name: "Paris",
      latitude: 48.8566,
      longitude: 2.3522,
      postal_code: "75001",
      country: "France",
      country_code: "fr",
      region: "Ile-de-France"
    )
  end

  it "asks for the current conditions when the offset is today" do
    client = instance_double(WeatherApi)
    allow(client).to receive(:fetch).and_return(JSON.parse(weather_current(name: "Paris")))

    forecast = described_class.new(client:).forecast(location:, days: 0)

    expect(client).to have_received(:fetch).with(query: "48.8566,2.3522", days: nil)
    expect(forecast.location_label).to include("Paris")
    expect(forecast.day_offset_label).to eq("Today")
    expect(forecast.temperature_c).to eq(18.2)
  end

  it "selects the requested future day" do
    client = instance_double(WeatherApi)
    allow(client).to receive(:fetch).and_return(JSON.parse(weather_forecast(name: "Paris", temp_f: 72.5)))

    forecast = described_class.new(client:).forecast(location:, days: 2)

    expect(client).to have_received(:fetch).with(query: "48.8566,2.3522", days: 3)
    expect(forecast.temperature_f).to eq(72.5)
    expect(forecast.day_offset_label).to eq("In 2 days")
    expect(forecast.forecast_date).to eq("2026-11-14")
  end
end
