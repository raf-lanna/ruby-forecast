require "rails_helper"

RSpec.describe Geocoding::Location do
  def build(**overrides)
    described_class.new(
      name: "Eiffel Tower",
      latitude: 48.8584,
      longitude: 2.2945,
      postal_code: nil,
      country: "France",
      country_code: "fr",
      region: "Ile-de-France",
      **overrides
    )
  end

  it "falls back to rounded coordinates when a postal code is missing" do
    expect(build.cache_identity).to eq("lat_lon:48.86:2.29")
    expect(build(postal_code: "  ").cache_identity).to eq("lat_lon:48.86:2.29")
  end

  it "uses the postal code when one is present" do
    expect(build(postal_code: "75007").cache_identity).to eq("postal:fr:75007")
    expect(build(postal_code: "94105", country_code: nil).cache_identity).to eq("postal:94105")
  end

  it "keeps a more precise coordinate query than the cache key" do
    expect(build.coordinate_query).to eq("48.8584,2.2945")
  end
end
