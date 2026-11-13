require "rails_helper"

RSpec.describe AddressQuery do
  it "accepts landmarks, regions, coordinates, and postal codes" do
    [
      "Eiffel Tower",
      "São Paulo",
      "94105",
      "-23.55, -46.63",
      "48°51'29.6\"N 2°17'40.2\"E"
    ].each do |address|
      expect(described_class.new(address:).valid?).to be(true)
    end
  end

  it "strips control characters and collapses whitespace" do
    query = described_class.new(address: "  Paris\u0000  France  ")

    expect(query.address).to eq("Paris France")
    expect(query).to be_valid
  end

  it "rejects short, long, and unsafe addresses" do
    [ "a", "a" * 201, "<script>", "", "..." ].each do |address|
      query = described_class.new(address:)

      expect(query).not_to be_valid
      expect(query.errors.full_messages).to include(described_class::INVALID_ADDRESS_MESSAGE)
    end
  end

  it "rejects a non-string address" do
    query = described_class.new(address: [ "Paris" ])

    expect(query.address).to eq("")
    expect(query).not_to be_valid
  end

  it "treats a blank day as today and rejects an out-of-range day" do
    expect(described_class.new(address: "Paris", days_from_now: "").days_from_now).to eq(0)
    expect(described_class.new(address: "Paris", days_from_now: "2")).to be_valid

    query = described_class.new(address: "Paris", days_from_now: "tomorrow")

    expect(query).not_to be_valid
    expect(query.errors.full_messages).to include(described_class::INVALID_DAY_MESSAGE)
  end
end
