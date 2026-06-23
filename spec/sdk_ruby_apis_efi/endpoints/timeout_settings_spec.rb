# frozen_string_literal: true

RSpec.describe SdkRubyApisEfi::Endpoints do
  describe "#timeout_settings" do
    def endpoints(options = {})
      described_class.new(options)
    end

    it "uses sane defaults when nothing is configured" do
      expect(endpoints.timeout_settings).to eq(connect: 10, write: 10, read: 30)
    end

    it "lets the :timeout option override individual keys" do
      expect(endpoints(timeout: { read: 15 }).timeout_settings)
        .to eq(connect: 10, write: 10, read: 15)
    end

    it "treats a numeric :timeout as a single global timeout" do
      expect(endpoints(timeout: 20).timeout_settings).to eq(20)
    end

    it "reads each timeout from its environment variable" do
      ENV["EFI_HTTP_CONNECT_TIMEOUT"] = "3"
      ENV["EFI_HTTP_WRITE_TIMEOUT"]   = "4"
      ENV["EFI_HTTP_READ_TIMEOUT"]    = "7"
      expect(endpoints.timeout_settings).to eq(connect: 3.0, write: 4.0, read: 7.0)
    end

    it "prefers the :timeout option over the environment variable" do
      ENV["EFI_HTTP_READ_TIMEOUT"] = "7"
      expect(endpoints(timeout: { read: 99 }).timeout_settings)
        .to eq(connect: 10, write: 10, read: 99)
    end

    it "ignores a non-numeric environment variable and falls back to the default" do
      ENV["EFI_HTTP_READ_TIMEOUT"] = "not-a-number"
      expect(endpoints.timeout_settings).to eq(connect: 10, write: 10, read: 30)
    end
  end
end
