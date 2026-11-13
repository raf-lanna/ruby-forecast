require "rails_helper"

RSpec.describe AddressGeocoder do
  let(:landmark) do
    nominatim_result(name: "Eiffel Tower", lat: 48.8584, lon: 2.2945)
  end

  it "builds an HTTP client with explicit timeouts" do
    http = instance_double(Http::Client)
    expect(Http::Client).to receive(:new).with(open_timeout: described_class::OPEN_TIMEOUT, read_timeout: described_class::READ_TIMEOUT).and_return(http)

    expect(described_class.new).to be_a(described_class)
  end

  it "resolves a landmark that has no postal code" do
    stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
      .with(headers: { "User-Agent" => described_class::USER_AGENT })
      .to_return(status: 200, body: landmark, headers: { "Content-Type" => "application/json" })

    location = described_class.geocode("Eiffel Tower")

    expect(location.name).to eq("Eiffel Tower")
    expect(location.postal_code).to be_nil
    expect(location.cache_identity).to eq("lat_lon:48.86:2.29")
  end

  it "keeps a postal code when the provider returns one" do
    body = nominatim_result(name: "Paris", lat: 48.8566, lon: 2.3522, postcode: "75001")
    stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
      .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

    expect(described_class.geocode("Paris").cache_identity).to eq("postal:fr:75001")
  end

  it "does not call Nominatim again for an identical address" do
    stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
      .to_return(status: 200, body: landmark, headers: { "Content-Type" => "application/json" })

    described_class.geocode("Eiffel Tower")
    described_class.geocode("  eiffel   tower ")

    expect(a_request(:get, /nominatim/)).to have_been_made.once
  end

  it "stores the lookup with an explicit TTL and race_condition_ttl" do
    cache = Class.new do
      attr_reader :options

      def fetch(_key, **options)
        @options = options
        yield
      end
    end.new
    http = instance_double(Http::Client, get: Http::Client::Response.new(status: 200, body: landmark))

    described_class.new(http:, cache:, min_interval: 0).geocode("Eiffel Tower")

    expect(cache.options).to include(expires_in: 30.minutes, race_condition_ttl: 10.seconds)
  end

  it "stops a second distinct lookup while the provider slot is held" do
    http = instance_double(Http::Client, get: Http::Client::Response.new(status: 200, body: landmark))
    geocoder = described_class.new(http:, cache: ActiveSupport::Cache::MemoryStore.new, min_interval: 30)

    geocoder.geocode("Eiffel Tower")

    expect { geocoder.geocode("Louvre") }.to raise_error(Providers::Unavailable)
    expect(http).to have_received(:get).once
  end

  it "raises when the provider rate-limits, fails, times out, or finds nothing" do
    stub = stub_request(:get, %r{nominatim\.openstreetmap\.org/search})

    stub.to_return(status: 429, body: "")
    expect { described_class.geocode("Paris") }.to raise_error(Providers::Unavailable)

    Rails.cache.clear
    stub.to_return(status: 503, body: "")
    expect { described_class.geocode("Paris") }.to raise_error(Providers::Unavailable)

    Rails.cache.clear
    stub.to_timeout
    expect { described_class.geocode("Paris") }.to raise_error(Providers::Unavailable)

    Rails.cache.clear
    stub.to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })
    expect { described_class.geocode("Paris") }.to raise_error(Providers::NotFound)

    Rails.cache.clear
    stub.to_raise(Errno::ECONNRESET)
    expect { described_class.geocode("Paris") }.to raise_error(Providers::Unavailable)
  end

  it "does not cache a provider failure" do
    http = instance_double(Http::Client)
    allow(http).to receive(:get).and_return(
      Http::Client::Response.new(status: 500, body: ""),
      Http::Client::Response.new(status: 200, body: landmark)
    )
    geocoder = described_class.new(http:, cache: ActiveSupport::Cache::MemoryStore.new, min_interval: 0)

    expect { geocoder.geocode("Eiffel Tower") }.to raise_error(Providers::Unavailable)
    expect(geocoder.geocode("Eiffel Tower").name).to eq("Eiffel Tower")
    expect(http).to have_received(:get).twice
  end
end
