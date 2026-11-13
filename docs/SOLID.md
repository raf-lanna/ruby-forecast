# SOLID in Ruby Weather

## S — Single Responsibility

- `WeatherController` extracts `params[:address]`, checks `AddressQuery`, and renders HTML or JSON.
- `Forecasts::Lookup` decides cache hit vs. provider call.
- `AddressGeocoder` talks to Nominatim.
- `WeatherForecaster` turns a location into a `Forecast`.
- `WeatherApi` and `Http::Client` own the HTTP calls, timeouts included.
- `Geocoding::Location` owns the postal-code or `lat_lon` cache identity.

## O — Open/Closed

`Forecasts::Lookup.new` accepts `geocoder:`, `forecaster:`, and `cache:`. A different provider or cache can be passed in without editing the lookup.

## L — Liskov Substitution

The defaults are the classes `AddressGeocoder` and `WeatherForecaster`. A test double that implements `geocode` or `forecast` can stand in for either one.

## I — Interface Segregation

The lookup calls `geocode(address)` and `forecast(location:, days:)`. It does not depend on Nominatim or WeatherAPI response shapes. Those stay inside the provider objects.

## D — Dependency Inversion

```ruby
def initialize(address, days: 0, geocoder: AddressGeocoder, forecaster: WeatherForecaster, cache: Rails.cache)
```

Production uses the real classes. Specs inject doubles. `Http::Client` is injected into the providers the same way, with `open_timeout` and `read_timeout` set by each provider.
