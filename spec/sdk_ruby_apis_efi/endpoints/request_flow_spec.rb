# frozen_string_literal: true

RSpec.describe SdkRubyApisEfi::Endpoints do
  describe "request lifecycle" do
    let(:base)    { "https://cobrancas-h.api.efipay.com.br" }
    let(:options) { { client_id: "id", client_secret: "secret", sandbox: true } }
    let(:client)  { SdkRubyApisEfi.new(options) }

    def stub_auth(status: 200)
      stub_request(:post, "#{base}/v1/authorize").to_return(
        status: status,
        body: { access_token: "TOKEN", token_type: "Bearer" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "authenticates, sends the request with the bearer token, and parses the JSON response" do
      auth = stub_auth
      charge = stub_request(:post, "#{base}/v1/charge")
        .with(headers: { "Authorization" => "Bearer TOKEN" })
        .to_return(
          status: 200,
          body: { code: 200, data: { charge_id: 1 } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      response = client.createCharge(body: { items: [] })

      expect(response).to eq("code" => 200, "data" => { "charge_id" => 1 })
      expect(auth).to have_been_requested
      expect(charge).to have_been_requested
    end

    it "raises when authentication is rejected (401)" do
      stub_auth(status: 401)
      expect { client.createCharge(body: {}) }.to raise_error(/unable to authenticate/)
    end

    it "interpolates path parameters into the route" do
      stub_auth
      detail = stub_request(:get, "#{base}/v1/charge/123")
        .to_return(status: 200, body: { code: 200 }.to_json)

      client.detailCharge(params: { id: 123 })

      expect(detail).to have_been_requested
    end

    it "returns a fallback payload when the response body is not JSON" do
      stub_auth
      stub_request(:post, "#{base}/v1/charge").to_return(status: 200, body: "<html>oops</html>")

      expect(client.createCharge(body: {})).to eq("{'code': 200}")
    end

    it "raises 'Method not found' for an unknown endpoint" do
      expect { client.totallyUnknownEndpoint }.to raise_error("Method not found")
    end

    it "applies the resolved per-operation timeouts to outgoing requests" do
      stub_auth
      stub_request(:post, "#{base}/v1/charge").to_return(status: 200, body: "{}")

      # Snapshot the argument at call time: httprb 4.x renames the hash keys
      # in place (:connect -> :connect_timeout), so a plain spy would observe
      # the mutated hash after the fact.
      captured = []
      allow(HTTP).to receive(:timeout).and_wrap_original do |original, *args|
        captured << args.first.dup
        original.call(*args)
      end

      client.createCharge(body: {})

      expect(captured).to include({ connect: 10, write: 10, read: 30 })
    end
  end
end
