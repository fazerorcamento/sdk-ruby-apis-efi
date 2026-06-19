# sdk-ruby-apis-efi

> A ruby gem for integration of your backend with the payment services
provided by [Efí](https://sejaefi.com.br/).


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sdk_ruby_apis_efi'
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install sdk_ruby_apis_efi
```

## Tested with
```
ruby 2.7.0
ruby 3.0.4
```

## Basic usage

```ruby
require 'sdk_ruby_apis_efi'

options = {
  client_id: CREDENTIALS::CLIENT_ID,
  client_secret: CREDENTIALS::CLIENT_SECRET,
  sandbox: CREDENTIALS::SANDBOX
}

efipay = SdkRubyApisEfi.new(options)

charge = {
  items: [{
    name: "Product A",
    value: 1000,
    amount: 2
  }]
}

response = efipay.createCharge(body: charge)
puts response
```

## Certificate (PEM) format

For the APIs that require mTLS (e.g. Pix), pass the path to your certificate
through the `certificate` option:

```ruby
options = {
  client_id: CREDENTIALS::CLIENT_ID,
  client_secret: CREDENTIALS::CLIENT_SECRET,
  certificate: "/path/to/certificate.pem",
  sandbox: false
}
```

The file **must be a single PEM containing both the client certificate and a
non-encrypted RSA private key**, for example:

```
-----BEGIN CERTIFICATE-----
... your certificate ...
-----END CERTIFICATE-----
-----BEGIN PRIVATE KEY-----
... your non-encrypted RSA private key ...
-----END PRIVATE KEY-----
```

The certificate is validated when the file is first used. If it is missing,
contains only the certificate (no key), or contains an **encrypted** private
key, the SDK raises `SdkRubyApisEfi::CertificateError` immediately with a clear
message — it never prompts for a passphrase and never hangs. If your `.p12`
exports an encrypted key, decrypt it first:

```bash
openssl rsa -in encrypted-key.pem -out key.pem        # remove the passphrase
cat certificate.crt key.pem > certificate.pem         # cert + key in one file
```

## HTTP timeouts

Every request is bounded by per-operation timeouts so a slow or unresponsive
Efí endpoint raises `HTTP::TimeoutError` instead of hanging the process. The
defaults (in seconds) are `connect: 10`, `write: 10`, `read: 30`.

Override them per key via the `timeout` option (or pass a single number for a
global timeout):

```ruby
options = {
  # ...
  timeout: { connect: 5, write: 5, read: 15 }
}

# or a single global timeout, in seconds:
options = { timeout: 20 }
```

Or via environment variables, which take effect without code changes:

```bash
EFI_HTTP_CONNECT_TIMEOUT=5
EFI_HTTP_WRITE_TIMEOUT=5
EFI_HTTP_READ_TIMEOUT=15
```

Precedence, per key: the `timeout` option, then the environment variable, then
the default. A timeout surfaces as `HTTP::TimeoutError` (a `StandardError`), so
it can be rescued by the caller.

## Examples

You can run the examples inside `examples` with the following command:

```bash
$ ruby examples/createCharge.rb
```

Just remember to set the correct credentials inside `examples/credentials.rb` before running.


## Additional documentation

The full documentation with all available endpoints is in https://dev.efipay.com.br/.

## Changelog

[CHANGELOG](https://github.com/efipay/sdk-ruby-apis-efi/tree/master/CHANGELOG.md)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/efipay/sdk-ruby-apis-efi. This project is intended to be a safe, welcoming space for collaboration.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).
