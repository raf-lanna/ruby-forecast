require "rails_helper"

RSpec.describe WeatherApi do
  let(:payload) { { "location" => { "name" => "Paris" }, "current" => { "temp_c" => 18.2 } }.to_json }

  it "builds an HTTP client with explicit timeouts" do
    http = instance_double(Http::Client)
    expect(Http::Client).to receive(:new).with(open_timeout: described_class::OPEN_TIMEOUT, read_timeout: described_class::READ_TIMEOUT).and_return(http)

    described_class.new
  end

  it "parses a successful response" do
    stub_request(:get, %r{api\.weatherapi\.com/v1/current\.json})
      .with(query: hash_including("key" => "test-key", "q" => "48.8600,2.3500"))
      .to_return(status: 200, body: payload, headers: { "Content-Type" => "application/json" })

    result = described_class.new.fetch(query: "48.8600,2.3500")

    expect(result.dig("location", "name")).to eq("Paris")
  end

  it "requests the forecast endpoint when a day count is present" do
    stub_request(:get, %r{api\.weatherapi\.com/v1/forecast\.json})
      .with(query: hash_including("days" => "3"))
      .to_return(status: 200, body: weather_forecast(name: "Paris", temp_f: 72), headers: { "Content-Type" => "application/json" })

    described_class.new.fetch(query: "Paris", days: 3)

    expect(a_request(:get, /forecast\.json/)).to have_been_made.once
  end

  it "maps rate limits, outages, timeouts, and connection drops to unavailable" do
    stub = stub_request(:get, %r{api\.weatherapi\.com/v1/current\.json})

    stub.to_return(status: 429, body: "")
    expect { described_class.new.fetch(query: "Paris") }.to raise_error(Providers::Unavailable)

    stub.to_return(status: 502, body: "<html></html>")
    expect { described_class.new.fetch(query: "Paris") }.to raise_error(Providers::Unavailable)

    stub.to_timeout
    expect { described_class.new.fetch(query: "Paris") }.to raise_error(Providers::Unavailable)

    stub.to_raise(SocketError.new("down"))
    expect { described_class.new.fetch(query: "Paris") }.to raise_error(Providers::Unavailable)
  end

  it "maps an unknown location to not found" do
    body = { error: { code: 1006, message: "No matching location found." } }.to_json
    stub_request(:get, %r{api\.weatherapi\.com/v1/current\.json})
      .to_return(status: 400, body: body, headers: { "Content-Type" => "application/json" })

    expect { described_class.new.fetch(query: "nowhere") }.to raise_error(Providers::NotFound)
  end

  it "fails closed when the API key is missing" do
    original = ENV.delete("WEATHER_API_KEY")

    expect { described_class.new.fetch(query: "Paris") }.to raise_error(Providers::Unavailable, /not configured/)
  ensure
    ENV["WEATHER_API_KEY"] = original || "test-key"
  end
end
