require 'net/http'
require 'uri'
require "http"
require "cgi"
require "json"
require 'base64'
require 'openssl'
require_relative "constants"
require_relative "status"
require_relative "version"
require_relative "errors"

module SdkRubyApisEfi
  class Endpoints

    # Sane defaults (in seconds) for the httprb per-operation timeouts. Any of
    # them can be overridden via the +:timeout+ option or the matching ENV var,
    # so an Efí endpoint that stops responding raises HTTP::TimeoutError instead
    # of hanging the Ruby process indefinitely.
    DEFAULT_CONNECT_TIMEOUT = 10
    DEFAULT_WRITE_TIMEOUT   = 10
    DEFAULT_READ_TIMEOUT    = 30

    # Markers that indicate the private key inside the PEM is encrypted. These
    # never appear in the base64 body of a certificate, so matching them is safe.
    ENCRYPTED_KEY_MARKERS = [
      "BEGIN ENCRYPTED PRIVATE KEY",
      "Proc-Type: 4,ENCRYPTED"
    ].freeze

    def initialize(options)
      super()
      @token = nil
      @options = options
      @charges = Constants::APIs::CHARGES
      @pix = Constants::APIs::PIX
      @open_finance = Constants::APIs::OPEN_FINANCE
      @payments = Constants::APIs::PAYMENTS
      @accounts_opening = Constants::APIs::ACCOUNTS_OPENING
    end
  
    def method_missing(name, **kwargs)
      if @charges[:ENDPOINTS].include?(name)
        @endpoints = @charges[:ENDPOINTS]
        @urls = @charges[:URL]
        request(@charges[:ENDPOINTS][name], **kwargs)

      elsif @pix[:ENDPOINTS].include?(name)
        @endpoints = @pix[:ENDPOINTS]
        @urls = @pix[:URL]
        request(@pix[:ENDPOINTS][name], **kwargs)
      
      elsif @open_finance[:ENDPOINTS].include?(name)
        @endpoints = @open_finance[:ENDPOINTS]
        @urls = @open_finance[:URL]
        request(@open_finance[:ENDPOINTS][name], **kwargs)
      
      elsif @payments[:ENDPOINTS].include?(name)
        @endpoints = @payments[:ENDPOINTS]
        @urls = @payments[:URL]
        request(@payments[:ENDPOINTS][name], **kwargs)
      
      elsif @accounts_opening[:ENDPOINTS].include?(name)
        @endpoints = @accounts_opening[:ENDPOINTS]
        @urls = @accounts_opening[:URL]
        request(@accounts_opening[:ENDPOINTS][name], **kwargs)
      
      else
        raise "Method not found"
      end
      
    end
  
    def request(settings, **kwargs)

      params = kwargs[:params] || {}
      body = kwargs[:body] || {}
      headers = kwargs[:headers] || {}

      get_url

      if @token.nil?
        authenticate
      end

    
      response = send(settings, params, body, headers)
      
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        "{'code': #{response.code}}"
      else
        JSON.parse(response.body)
      end
  
    end
  
    def send(settings, params, body, headersComplement)
      url = build_url(settings[:route], params)
      if body == {}
        body = nil
      end
      headers = {
        "accept" => "application/json",
        "api-sdk" => "efi-ruby-#{SdkRubyApisEfi::VERSION}"
      }
      
      if headersComplement.any?
        headersComplement.each do |key, value|
          headers[key] = value
        end
      end
  
      if @options.has_key?(:partner_token)
        headers['partner-token'] = @options[:partner_token]
      end

      
      if @options[:"x-skip-mtls-checking"]
        headers["x-skip-mtls-checking"] = @options[:"x-skip-mtls-checking"]
      end

      @token = @token.parse

      client = HTTP
        .timeout(timeout_settings)
        .headers(headers)
        .auth("Bearer #{@token['access_token']}")
        .method(settings[:method])

      if ssl_context
        client.call(url, json: body, ssl_context: ssl_context)
      else
        client.call(url, json: body)
      end

    end

    def authenticate

      url = build_url(@endpoints[:authorize][:route], {})

      headers = {
        "accept" => "application/json",
        "api-sdk" => "efi-ruby-#{SdkRubyApisEfi::VERSION}"  
      }

      auth_headers = {
        user: @options[:client_id],
        pass: @options[:client_secret]
      }
      
      auth_body =  {grant_type: :client_credentials}

      client = HTTP
        .timeout(timeout_settings)
        .headers(headers)
        .basic_auth(auth_headers)

      response =
        if ssl_context
          client.post(url, json: auth_body, ssl_context: ssl_context)
        else
          client.post(url, json: auth_body)
        end
  
      if response.status.to_s == STATUS::UNAUTHORIZED
        fail "unable to authenticate"
      else
        @token = response
      end
    end

    # Resolves the httprb per-operation timeouts. Precedence, per key:
    # the +:timeout+ option, then the matching ENV var, then the default.
    # A numeric +:timeout+ option is honored as a single global timeout.
    def timeout_settings
      return @options[:timeout] if @options[:timeout].is_a?(Numeric)

      overrides = @options[:timeout].is_a?(Hash) ? @options[:timeout] : {}
      {
        connect: overrides[:connect] || env_timeout("EFI_HTTP_CONNECT_TIMEOUT") || DEFAULT_CONNECT_TIMEOUT,
        write:   overrides[:write]   || env_timeout("EFI_HTTP_WRITE_TIMEOUT")   || DEFAULT_WRITE_TIMEOUT,
        read:    overrides[:read]    || env_timeout("EFI_HTTP_READ_TIMEOUT")    || DEFAULT_READ_TIMEOUT
      }
    end

    # Reads a timeout (in seconds) from an ENV var, returning nil when unset or
    # not a number so resolution falls back to the default.
    def env_timeout(name)
      value = ENV[name]
      return nil if value.nil? || value.empty?

      Float(value, exception: false)
    end

    # Builds (once) the SSL context used for mTLS requests, or nil when no
    # certificate is configured. Memoized so the PEM file is read and parsed a
    # single time per instance instead of twice on every request.
    def ssl_context
      return @ssl_context if defined?(@ssl_context)

      unless @options.has_key?(:certificate)
        return @ssl_context = nil
      end

      cert, key = load_certificate
      @ssl_context = OpenSSL::SSL::SSLContext.new.tap do |ctx|
        ctx.set_params(cert: cert, key: key)
      end
    end

    # Reads and validates the configured PEM file, failing fast with a clear
    # CertificateError instead of hanging on a passphrase prompt. Expects a
    # single file with the client certificate and a non-encrypted RSA key.
    def load_certificate
      path = @options[:certificate]

      begin
        pem = File.read(path)
      rescue SystemCallError => e
        raise CertificateError, "Unable to read the certificate file '#{path}': #{e.message}"
      end

      if ENCRYPTED_KEY_MARKERS.any? { |marker| pem.include?(marker) }
        raise CertificateError,
              "The certificate file '#{path}' contains an encrypted private key. " \
              "Provide a PEM with a non-encrypted RSA private key (the SDK does not support passphrases)."
      end

      unless pem.include?("-----BEGIN CERTIFICATE-----")
        raise CertificateError, "No certificate found in '#{path}'. Expected a '-----BEGIN CERTIFICATE-----' block."
      end

      unless pem.match?(/-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----/)
        raise CertificateError,
              "No private key found in '#{path}'. The PEM must contain both the certificate " \
              "and a non-encrypted RSA private key."
      end

      # An empty passphrase is passed so OpenSSL never falls back to prompting
      # the (possibly absent) TTY, which is itself a freeze vector.
      [OpenSSL::X509::Certificate.new(pem), OpenSSL::PKey::RSA.new(pem, "")]
    rescue OpenSSL::OpenSSLError => e
      raise CertificateError, "Failed to load the certificate file '#{path}': #{e.message}"
    end

    def get_url
      @base_url = @urls[:sandbox]
      if @options.has_key?(:sandbox)
        @base_url = @options[:sandbox] ? @urls[:sandbox] : @urls[:production]
      end

    end
  
    def build_url(route, params)
      params = {} if params.nil?
      route = remove_placeholders(route, params)
      complete_url = complete_url(route, params)
      
    end
  
    def remove_placeholders(route, params)
      regex = /\:(\w+)/
      route.scan(regex).each do |key|
        key = key[0]
        value = params[key.to_sym].to_s
        route = route.gsub(":#{key}", value)
        params.delete(key.to_sym)
      end

      return route
    end
    
    def query_string(params)
      mapped = params.map { |p, value| "#{p}=#{value}" }
      mapped.join('&')
    end

    def map_params(params)
      params.map do |key|
        "#{key[0]}=#{CGI.escape(key[1].to_s)}"
      end.join("&")
    end
    
    def complete_url(route, params)
      mapped = map_params(params)
      if !mapped.empty?
        "#{@base_url}#{route}?#{mapped}"
      else
        "#{@base_url}#{route}"
      end
    end
    
  end
end

