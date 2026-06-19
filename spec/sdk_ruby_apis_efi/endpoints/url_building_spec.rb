# frozen_string_literal: true

RSpec.describe SdkRubyApisEfi::Endpoints do
  describe "URL building" do
    subject(:client) { SdkRubyApisEfi.new({}) }

    before { client.instance_variable_set(:@base_url, "https://api.example.com") }

    it "substitutes path placeholders from params" do
      expect(client.build_url("/v1/charge/:id", { id: 42 }))
        .to eq("https://api.example.com/v1/charge/42")
    end

    it "appends remaining params as an escaped query string" do
      expect(client.build_url("/v1/charges", { status: "paid up" }))
        .to eq("https://api.example.com/v1/charges?status=paid+up")
    end

    it "produces no query string when there are no params" do
      expect(client.build_url("/v1/charges", {})).to eq("https://api.example.com/v1/charges")
    end

    it "consumes the placeholder param instead of leaking it into the query string" do
      expect(client.build_url("/v1/charge/:id/metadata", { id: 7 }))
        .to eq("https://api.example.com/v1/charge/7/metadata")
    end
  end
end
