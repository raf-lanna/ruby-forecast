# Ruby Weather

Rails app that turns an address into a weather forecast. OpenStreetMap Nominatim resolves the place. WeatherAPI.com supplies the conditions. The same endpoint renders HTML and JSON.

A postal code is optional. Landmarks, coordinates, and regions that do not have one still return a forecast.

## Local setup

Ruby `3.3.5`. The app does not use a relational database. Forecasts live in Redis for 30 minutes.

### Docker Compose

Starts the Rails app and Redis together:

```bash
export WEATHER_API_KEY=your-key
docker compose up --build
```

Open `http://localhost:3000/weather`.

JSON:

```bash
curl -H "Accept: application/json" \
  "http://localhost:3000/weather/forecast?address=Eiffel%20Tower"
```

`WEATHER_API_KEY` can also live in a `.env` file in the project root. Compose reads it for interpolation. Set `SECRET_KEY_BASE` when you deploy this image for real; the compose file supplies a local default.

### Host process, Redis in Docker

```bash
docker compose up redis -d
bundle install
```

Create a `.env` file:

```bash
WEATHER_API_KEY=your-key
REDIS_URL=redis://localhost:6379/0
```

```bash
bin/rails server
```

Development uses the same Redis cache store as production, so a forecast cached by one Puma worker is visible to the others.

## HTTP API

`GET /weather/forecast`

| Query | Required | Notes |
| --- | --- | --- |
| `address` | yes | 2–200 characters. City, landmark, region, postal code, or coordinates. |
| `days_from_now` | no | Integer `0`–`5`. Defaults to today. |

Send `Accept: text/html` or `Accept: application/json`.

| Status | When |
| --- | --- |
| 200 | Forecast rendered as HTML or JSON. |
| 422 | Address failed validation, the day is out of range, or the place could not be resolved. |
| 503 | Timeout, dropped connection, upstream 429, or upstream 5xx. |

JSON body on success:

```json
{
  "address": "Eiffel Tower",
  "cache_hit": false,
  "location": { "cache_key": "lat_lon:48.86:2.29" },
  "forecast": { "temperature_c": 18.2 }
}
```

`location.cache_key` is `postal:<country>:<code>` when Nominatim returns a postal code, and `lat_lon:<lat>:<lon>` otherwise.

## Tests and lint

```bash
bundle exec rspec
bundle exec rubocop
bundle exec brakeman --no-pager
```

External HTTP is stubbed with WebMock. The test environment uses a memory cache so TTL examples stay deterministic. CI still boots Redis, then runs RuboCop, Brakeman, and `bundle exec rspec`.

## Architectural Decisions & Trade-offs

### Cache boundary

There are two `Rails.cache.fetch` layers, each with `expires_in: 30.minutes`. Nothing is written to a relational table.

1. **Address cache** (`geocode:v1:<normalized address>`). Nominatim allows about one request per second. An identical address, ignoring case and extra whitespace, is served from this entry and does not call Nominatim again. The weather lookup is not even started until this returns a location.
2. **Forecast cache**, keyed only after geocoding. When the location has a postal code the key is `postal:<country>:<code>`. When it does not — a landmark, a coordinate pair, or a region — the key falls back to coordinates rounded to two decimal places, for example `lat_lon:48.86:2.29`. The day offset is part of the key, so today and “in 2 days” do not collide.

Rounding is the trade-off that makes the fallback useful: places within about a kilometer share one WeatherAPI call, and a postal code shares one forecast across that code. The weather request itself still uses four-decimal coordinates, so the cached payload is a real point forecast, not a rounded one. The first writer wins for 30 minutes.

Provider failures are not stored. A 429 or 5xx on the first attempt can succeed on the next one. Geocoding and forecasting stay behind those cache keys, so a cache hit never touches either upstream.

### Concurrency protection

Both fetches pass `race_condition_ttl: 10.seconds`. After a hot key expires, one worker regenerates it and the others keep receiving the previous value for those 10 seconds instead of stampeding the provider. That extension only helps when every worker reads the same store. Redis is the development and production cache. A process-local memory store would split the cache across Puma workers, so `:memory_store` is configured only in `config/environments/test.rb`. `config/application.rb` does not set a cache store.

Nominatim has a second guard: a cache `write` with `unless_exist` holds a one-second slot around the real HTTP call. Cache hits do not take the slot. If the slot is already held, the request returns 503 instead of queueing another geocode. The slot fails fast on purpose; waiting in the request would hide overload and still risk the provider limit.

### Provider error handling

`Http::Client` is the only component that opens a socket. `AddressGeocoder` uses it with `open_timeout: 3` and `read_timeout: 5`. `WeatherApi` uses it with `open_timeout: 5` and `read_timeout: 8`. Timeouts, connection resets, HTTP 429, and HTTP 5xx become `Providers::Unavailable`. An empty geocoder result or WeatherAPI code 1006 becomes `Providers::NotFound`.

`WeatherController` only extracts `params[:address]`, strips control characters, and renders. `AddressQuery` enforces length and the allowed character set before any provider is called. `Forecasts::Lookup` orchestrates the two caches. Its constructor takes the collaborators with class defaults:

```ruby
initialize(address, days: 0, geocoder: AddressGeocoder, forecaster: WeatherForecaster, cache: Rails.cache)
```

Specs pass doubles, so they do not stub class methods. `Geocoding::Location`, `Forecast`, and the lookup result are `Data.define` value objects.

The controller maps `NotFound` to **422** and `Unavailable` to **503**, for both `format.html` and `format.json`. A Redis outage is translated to `Unavailable` as well, so it follows the same 503 path. Upstream failures do not bubble up as an unhandled 500.
