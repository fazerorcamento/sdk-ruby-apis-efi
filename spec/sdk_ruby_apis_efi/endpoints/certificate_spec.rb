# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe SdkRubyApisEfi::Endpoints do
  describe "#ssl_context (PEM validation)" do
    before(:all) do
      @tmpdir = Dir.mktmpdir("efi-pem")

      key  = OpenSSL::PKey::RSA.new(2048)
      name = OpenSSL::X509::Name.parse("/CN=efi-test")
      cert = OpenSSL::X509::Certificate.new
      cert.version    = 2
      cert.serial     = 1
      cert.subject    = name
      cert.issuer     = name
      cert.public_key = key.public_key
      cert.not_before = Time.now - 60
      cert.not_after  = Time.now + 3600
      cert.sign(key, OpenSSL::Digest.new("SHA256"))

      cipher = OpenSSL::Cipher.new("aes-256-cbc")

      @valid_pem           = write_pem("valid.pem",     cert.to_pem + key.to_pem)
      @cert_only_pem       = write_pem("cert_only.pem", cert.to_pem)
      @key_only_pem        = write_pem("key_only.pem",  key.to_pem)
      @encrypted_pkcs1_pem = write_pem("enc_pkcs1.pem", cert.to_pem + key.to_pem(cipher, "secret"))
      @encrypted_pkcs8_pem = write_pem("enc_pkcs8.pem", cert.to_pem + key.private_to_pem(cipher, "secret"))
      @malformed_pem       = write_pem(
        "malformed.pem",
        "-----BEGIN CERTIFICATE-----\nnot-base64\n-----END CERTIFICATE-----\n" \
        "-----BEGIN PRIVATE KEY-----\nnot-base64\n-----END PRIVATE KEY-----\n"
      )
      @missing_pem = File.join(@tmpdir, "does_not_exist.pem")
    end

    after(:all) { FileUtils.remove_entry(@tmpdir) }

    def write_pem(name, contents)
      path = File.join(@tmpdir, name)
      File.write(path, contents)
      path
    end

    def endpoints(certificate: nil)
      options = {}
      options[:certificate] = certificate if certificate
      described_class.new(options)
    end

    it "returns nil when no certificate is configured (non-mTLS path)" do
      expect(endpoints.ssl_context).to be_nil
    end

    it "builds an SSLContext with the cert and key for a valid PEM" do
      context = endpoints(certificate: @valid_pem).ssl_context
      expect(context).to be_a(OpenSSL::SSL::SSLContext)
      expect(context.cert).to be_a(OpenSSL::X509::Certificate)
      expect(context.key).to be_a(OpenSSL::PKey::RSA)
    end

    it "memoizes the context so the file is read and parsed only once" do
      client = endpoints(certificate: @valid_pem)
      expect(client.ssl_context).to be(client.ssl_context)
    end

    it "raises a clear error for a missing file" do
      expect { endpoints(certificate: @missing_pem).ssl_context }
        .to raise_error(SdkRubyApisEfi::CertificateError, /Unable to read/)
    end

    it "raises when the PEM contains only the certificate (no private key)" do
      expect { endpoints(certificate: @cert_only_pem).ssl_context }
        .to raise_error(SdkRubyApisEfi::CertificateError, /private key/)
    end

    it "raises when the PEM contains only the key (no certificate)" do
      expect { endpoints(certificate: @key_only_pem).ssl_context }
        .to raise_error(SdkRubyApisEfi::CertificateError, /certificate/)
    end

    it "raises for a PKCS#1 encrypted key instead of prompting for a passphrase" do
      expect { endpoints(certificate: @encrypted_pkcs1_pem).ssl_context }
        .to raise_error(SdkRubyApisEfi::CertificateError, /encrypted/i)
    end

    it "raises for a PKCS#8 encrypted key instead of prompting for a passphrase" do
      expect { endpoints(certificate: @encrypted_pkcs8_pem).ssl_context }
        .to raise_error(SdkRubyApisEfi::CertificateError, /encrypted/i)
    end

    it "wraps an OpenSSL parse error in a CertificateError" do
      expect { endpoints(certificate: @malformed_pem).ssl_context }
        .to raise_error(SdkRubyApisEfi::CertificateError, /Failed to load/)
    end

    it "fails fast for an encrypted key (well under a second, never hangs)" do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect { endpoints(certificate: @encrypted_pkcs1_pem).ssl_context }
        .to raise_error(SdkRubyApisEfi::CertificateError)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      expect(elapsed).to be < 1.0
    end
  end
end
