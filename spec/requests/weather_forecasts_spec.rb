require "rails_helper"

RSpec.describe "Weather forecasts", type: :request do
  let(:address) { "Eiffel Tower" }
  let(:geocode_body) { nominatim_result(name: "Eiffel Tower", lat: 48.8584, lon: 2.2945) }
  let(:current_body) { weather_current(name: "Eiffel Tower") }

  def stub_success
    stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
      .to_return(status: 200, body: geocode_body, headers: { "Content-Type" => "application/json" })
    stub_request(:get, %r{api\.weatherapi\.com/v1/current\.json})
      .to_return(status: 200, body: current_body, headers: { "Content-Type" => "application/json" })
  end

  it "renders HTML and JSON for a place without a postal code" do
    stub_success

    get weather_forecast_path, params: { address:, days_from_now: 0 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Eiffel Tower")
    expect(response.body).to include("weather-card__back")
    expect(response.body).not_to include("weather-back-link")
    expect(response.body).not_to include(AddressQuery::CACHE_MESSAGE)

    get weather_forecast_path, params: { address:, days_from_now: 0 }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    body = response.parsed_body
    expect(body["cache_hit"]).to be(true)
    expect(body["location"]["postal_code"]).to be_nil
    expect(body["location"]["cache_key"]).to eq("lat_lon:48.86:2.29")
    expect(body["forecast"]["temperature_c"]).to eq(18.2)
    expect(a_request(:get, /nominatim/)).to have_been_made.once
    expect(a_request(:get, /weatherapi/)).to have_been_made.once
  end

  it "serves a repeated HTML search from the cache" do
    stub_success

    get weather_forecast_path, params: { address: }
    get weather_forecast_path, params: { address: }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(AddressQuery::CACHE_MESSAGE)
    expect(response.body).to include('data-controller="flash"')
    expect(response.body).to include('aria-label="Dismiss"')
    expect(a_request(:get, /nominatim|weatherapi/)).to have_been_made.twice
  end

  it "requests the selected future day" do
    stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
      .to_return(status: 200, body: geocode_body, headers: { "Content-Type" => "application/json" })
    stub_request(:get, %r{api\.weatherapi\.com/v1/forecast\.json})
      .with(query: hash_including("days" => "3"))
      .to_return(status: 200, body: weather_forecast(name: "Eiffel Tower", temp_f: 72.5), headers: { "Content-Type" => "application/json" })

    get weather_forecast_path, params: { address:, days_from_now: 2 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("72.5")
    expect(response.body).to include("In 2 days")
  end

  it "rejects an invalid address before calling a provider" do
    get weather_forecast_path, params: { address: "a", days_from_now: 3 }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include(AddressQuery::INVALID_ADDRESS_MESSAGE)
    expect(response.body).to include('value="a"')
    expect(response.body).to include('value="3"')
    expect(a_request(:any, /nominatim|weatherapi/)).not_to have_been_made
  end

  it "rejects an invalid address as JSON" do
    get weather_forecast_path, params: { address: "<script>" }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to eq(AddressQuery::INVALID_ADDRESS_MESSAGE)
  end

  it "rejects an invalid forecast day" do
    get weather_forecast_path, params: { address:, days_from_now: "tomorrow" }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to eq(AddressQuery::INVALID_DAY_MESSAGE)
    expect(a_request(:any, /nominatim|weatherapi/)).not_to have_been_made
  end

  it "returns 422 when the place cannot be found" do
    stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
      .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

    get weather_forecast_path, params: { address: }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to eq(AddressQuery::NOT_FOUND_MESSAGE)
  end

  it "returns 503 when geocoding times out or rate-limits" do
    stub = stub_request(:get, %r{nominatim\.openstreetmap\.org/search})

    stub.to_timeout
    get weather_forecast_path, params: { address: }, as: :json
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body["error"]).to eq(AddressQuery::TRY_AGAIN_MESSAGE)

    Rails.cache.clear
    stub.to_return(status: 429, body: "")
    get weather_forecast_path, params: { address: }
    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include("Please try again shortly.")
    expect(a_request(:get, /weatherapi/)).not_to have_been_made
  end

  it "returns 503 for an upstream outage and allows a later success" do
    stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
      .to_return(status: 200, body: geocode_body, headers: { "Content-Type" => "application/json" })
    weather = stub_request(:get, %r{api\.weatherapi\.com/v1/current\.json})
    weather.to_return(status: 500, body: "")

    get weather_forecast_path, params: { address: }, as: :json
    expect(response).to have_http_status(:service_unavailable)

    weather.to_return(status: 200, body: current_body, headers: { "Content-Type" => "application/json" })
    get weather_forecast_path, params: { address: }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["cache_hit"]).to be(false)
    expect(a_request(:get, /nominatim/)).to have_been_made.once
    expect(a_request(:get, /weatherapi/)).to have_been_made.twice
  end

  it "sanitizes the address before the lookup" do
    stub_success

    get weather_forecast_path, params: { address: "  Eiffel   Tower \u0000" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(a_request(:get, /nominatim/).with(query: hash_including("q" => "Eiffel Tower"))).to have_been_made.once
  end
end
