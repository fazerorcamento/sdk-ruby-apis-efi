# frozen_string_literal: true

module SdkRubyApisEfi
  # Base class for all errors raised by the SDK.
  class Error < StandardError; end

  # Raised when the configured certificate (PEM) file cannot be loaded.
  #
  # The SDK expects a single PEM file containing both the client certificate
  # and its **non-encrypted** RSA private key. This error is raised, instead of
  # hanging or prompting for a passphrase, when the file is missing, encrypted,
  # contains only the certificate (no key), or is otherwise malformed.
  class CertificateError < Error; end
end
