class AddressQuery
  include ActiveModel::Model

  MIN_LENGTH = 2
  MAX_LENGTH = 200
  MAX_DAYS = 5
  FORMAT = /\A[\p{L}\p{N}\s,.'’"#\/()\-+°:;]+\z/
  PLACE_TEXT = /[\p{L}\p{N}]/

  CACHE_MESSAGE = "This forecast came from cache and may be up to 30 minutes old."
  NOT_FOUND_MESSAGE = "We couldn't find a location for that address."
  TRY_AGAIN_MESSAGE = "We couldn't fetch the forecast right now. Please try again shortly."
  INVALID_ADDRESS_MESSAGE = "Enter a place, landmark, coordinates, or region (2-200 characters)."
  INVALID_DAY_MESSAGE = "Choose a forecast day between today and 5 days ahead."

  attr_reader :address, :days_from_now

  validate :address_constraints
  validate :days_constraints

  def initialize(address: nil, days_from_now: nil)
    @address = sanitize_address(address)
    @days_from_now = normalize_days(days_from_now)
  end

  private

  def sanitize_address(value)
    return "" unless value.is_a?(String)

    value.gsub(/[\u0000-\u001F\u007F]/, " ").gsub(/\s+/, " ").strip
  end

  def normalize_days(value)
    return 0 if value.nil? || (value.is_a?(String) && value.strip.empty?)
    return value if value.is_a?(Integer)

    string = value.to_s.strip
    return string.to_i if string.match?(/\A\d+\z/)

    string
  end

  def address_constraints
    return if address.length.between?(MIN_LENGTH, MAX_LENGTH) && address.match?(FORMAT) && address.match?(PLACE_TEXT)

    errors.add(:base, INVALID_ADDRESS_MESSAGE)
  end

  def days_constraints
    return if days_from_now.is_a?(Integer) && days_from_now.between?(0, MAX_DAYS)

    errors.add(:base, INVALID_DAY_MESSAGE)
  end
end
