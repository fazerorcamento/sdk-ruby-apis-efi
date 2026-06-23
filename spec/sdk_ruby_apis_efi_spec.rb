# frozen_string_literal: true

RSpec.describe SdkRubyApisEfi do
  it "exposes a version number" do
    expect(SdkRubyApisEfi::VERSION).to be_a(String)
  end

  describe ".new" do
    it "returns an Endpoints instance" do
      client = SdkRubyApisEfi.new(client_id: "id", client_secret: "secret")
      expect(client).to be_a(SdkRubyApisEfi::Endpoints)
    end
  end
end
