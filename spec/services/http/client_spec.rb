require "rails_helper"

RSpec.describe Http::Client do
  let(:http) { FakeHttp.new(instance_double(Net::HTTPSuccess, code: "200", body: "{\"ok\":true}")) }

  it "applies open and read timeouts to the connection" do
    described_class.new(open_timeout: 3, read_timeout: 5, http_class: http).get("https://example.com/weather")

    expect(http.start_kwargs).to include(use_ssl: true, open_timeout: 3, read_timeout: 5)
  end

  it "returns the status and body" do
    response = described_class.new(http_class: http).get("https://example.com/weather")

    expect(response).to eq(described_class::Response.new(status: 200, body: "{\"ok\":true}"))
  end

  it "turns dropped connections and timeouts into an unavailable provider" do
    http.exception = Errno::ECONNRESET.new
    expect { described_class.new(http_class: http).get("https://example.com/weather") }.to raise_error(Providers::Unavailable)

    http.exception = Net::ReadTimeout.new("read")
    expect { described_class.new(http_class: http).get("https://example.com/weather") }.to raise_error(Providers::Unavailable)
  end
end

class FakeHttp
  attr_reader :start_kwargs
  attr_accessor :exception

  def initialize(response)
    @response = response
  end

  def start(*_args, **kwargs)
    @start_kwargs = kwargs
    raise exception if exception

    yield self
  end

  def request(_request)
    @response
  end
end
