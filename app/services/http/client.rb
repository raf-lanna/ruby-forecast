require "net/http"
require "uri"
require "openssl"

module Http
  class Client
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 8

    Response = Data.define(:status, :body)

    def initialize(open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, http_class: Net::HTTP)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @http_class = http_class
    end

    def get(url, headers: {})
      uri = url.is_a?(URI) ? url : URI.parse(url.to_s)
      response = @http_class.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: @open_timeout,
        read_timeout: @read_timeout
      ) do |http|
        request = Net::HTTP::Get.new(uri)
        headers.each { |key, value| request[key] = value }
        http.request(request)
      end

      Response.new(status: response.code.to_i, body: response.body.to_s)
    rescue Timeout::Error, SocketError, EOFError, IOError, OpenSSL::SSL::SSLError, SystemCallError => e
      raise Providers::Unavailable.new("Upstream connection failed (#{e.class})")
    end
  end
end
