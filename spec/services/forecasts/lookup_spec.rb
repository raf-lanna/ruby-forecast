require "rails_helper"

RSpec.describe Forecasts::Lookup do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:location) do
    Geocoding::Location.new(
      name: "Eiffel Tower",
      latitude: 48.8584,
      longitude: 2.2945,
      postal_code: nil,
      country: "France",
      country_code: "fr",
      region: "Ile-de-France"
    )
  end
  let(:forecast) { Forecast.from_api_response(JSON.parse(weather_current(name: "Eiffel Tower"))) }
  let(:geocoder) { instance_double(AddressGeocoder) }
  let(:forecaster) { instance_double(WeatherForecaster) }

  before do
    allow(geocoder).to receive(:geocode).and_return(location)
    allow(forecaster).to receive(:forecast).and_return(forecast)
  end

  def lookup_for(address, geocoder: self.geocoder, forecaster: self.forecaster)
    described_class.new(address, geocoder:, forecaster:, cache:)
  end

  it "injects the geocoder and forecaster classes by default" do
    service = described_class.new("Eiffel Tower", cache:)

    expect(service.instance_variable_get(:@geocoder)).to eq(AddressGeocoder)
    expect(service.instance_variable_get(:@forecaster)).to eq(WeatherForecaster)
  end

  it "marks the first lookup as a cache miss and the second as a hit" do
    first = lookup_for("Eiffel Tower").call
    second = lookup_for("Eiffel Tower").call

    expect(first.cache_hit).to be(false)
    expect(second.cache_hit).to be(true)
    expect(forecaster).to have_received(:forecast).once
  end

  it "passes an explicit TTL and race_condition_ttl to the forecast cache" do
    recorder = Class.new do
      attr_reader :options

      def fetch(_key, **options)
        @options = options
        yield
      end
    end.new

    described_class.new("Eiffel Tower", geocoder:, forecaster:, cache: recorder).call

    expect(recorder.options).to include(expires_in: 30.minutes, race_condition_ttl: 10.seconds)
  end

  it "shares one forecast for addresses that resolve to the same rounded coordinates" do
    nearby = location.with(name: "Champ de Mars", latitude: 48.8591, longitude: 2.2939)
    allow(geocoder).to receive(:geocode).with("Eiffel Tower").and_return(location)
    allow(geocoder).to receive(:geocode).with("Champ de Mars").and_return(nearby)

    lookup_for("Eiffel Tower").call
    lookup_for("Champ de Mars").call

    expect(location.cache_identity).to eq(nearby.cache_identity)
    expect(forecaster).to have_received(:forecast).once
  end

  it "shares one forecast for the same postal code" do
    first = location.with(postal_code: "75007", latitude: 48.85)
    second = location.with(postal_code: "75007", latitude: 48.90, name: "Seventh")
    allow(geocoder).to receive(:geocode).with("Tower").and_return(first)
    allow(geocoder).to receive(:geocode).with("Museum").and_return(second)

    lookup_for("Tower").call
    lookup_for("Museum").call

    expect(forecaster).to have_received(:forecast).once
  end

  it "fetches again after the TTL expires" do
    lookup_for("Eiffel Tower").call

    travel 31.minutes do
      result = lookup_for("Eiffel Tower").call
      expect(result.cache_hit).to be(false)
    end

    expect(forecaster).to have_received(:forecast).twice
  end

  it "does not cache a provider failure" do
    calls = 0
    allow(forecaster).to receive(:forecast) do
      calls += 1
      raise Providers::Unavailable.new("down") if calls == 1

      forecast
    end

    expect { lookup_for("Eiffel Tower").call }.to raise_error(Providers::Unavailable)
    expect(lookup_for("Eiffel Tower").call.cache_hit).to be(false)
    expect(calls).to eq(2)
  end

  it "serializes the result for the JSON endpoint" do
    payload = lookup_for("Eiffel Tower").call.as_json

    expect(payload[:cache_hit]).to be(false)
    expect(payload[:location][:cache_key]).to eq("lat_lon:48.86:2.29")
    expect(payload[:forecast][:temperature_c]).to eq(18.2)
  end
end
