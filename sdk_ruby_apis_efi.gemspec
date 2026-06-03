# frozen_string_literal: true

require_relative "lib/sdk_ruby_apis_efi/version"

Gem::Specification.new do |spec|
  spec.name = "sdk_ruby_apis_efi"
  spec.version = SdkRubyApisEfi::VERSION
  spec.authors = ["Debora Amaral"]
  spec.email = ["consultoria@sejaefi.com.br"]

  spec.summary       = "Efí Pay API Ruby Gem"
  spec.description   = "A ruby gem for integration of your backend with the
                        payment services provided by Efí Pay"

  spec.homepage      = "https://github.com/efipay/sdk-ruby-apis-efi"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"


  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features|examples)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rake", ">= 12.3.3"
  spec.add_dependency "http"
  spec.add_dependency "cgi", ">= 0.4.2"
  spec.add_dependency "json", ">= 2.19.2"
  spec.add_dependency "base64"
  spec.add_dependency "uri", ">= 0.12.5"
end
