module Providers
  class Error < StandardError
    attr_reader :http_status

    def initialize(message = nil, http_status: nil)
      super(message)
      @http_status = http_status
    end
  end
end
