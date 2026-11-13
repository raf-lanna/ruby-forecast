class WeatherController < ApplicationController
  def index
    @address_query = AddressQuery.new
  end

  def forecast
    @address_query = build_address_query

    unless @address_query.valid?
      render_failure(@address_query.errors.full_messages.first, :unprocessable_entity)
      return
    end

    @result = Forecasts::Lookup.new(
      @address_query.address,
      days: @address_query.days_from_now
    ).call
    @forecast = @result.forecast
    render_forecast
  rescue Providers::NotFound => e
    Rails.logger.info("Address lookup missed: #{e.message}")
    render_failure(AddressQuery::NOT_FOUND_MESSAGE, :unprocessable_entity)
  rescue Providers::Unavailable => e
    Rails.logger.warn("Forecast lookup unavailable: #{e.message}")
    render_failure(AddressQuery::TRY_AGAIN_MESSAGE, :service_unavailable)
  end

  private

  def build_address_query
    AddressQuery.new(address: sanitized_address, days_from_now: days_param)
  end

  def sanitized_address
    raw = params[:address]
    return "" unless raw.is_a?(String)

    raw.gsub(/[\u0000-\u001F\u007F]/, " ").gsub(/\s+/, " ").strip
  end

  def days_param
    params[:days_from_now]
  end

  def render_forecast
    respond_to do |format|
      format.html do
        flash.now[:notice] = AddressQuery::CACHE_MESSAGE if @result.cache_hit
        render :forecast, status: :ok
      end
      format.json { render json: @result, status: :ok }
    end
  end

  def render_failure(message, status)
    respond_to do |format|
      format.html do
        flash.now[:alert] = message
        render :index, status: status
      end
      format.json { render json: { error: message }, status: status }
    end
  end
end
