require "rails_helper"

RSpec.describe PlacesClient do
  let(:endpoint) { PlacesClient::ENDPOINT }
  let(:api_key) { "test-key" }

  def page(name)
    Rails.root.join("spec/fixtures/places/#{name}.json").read
  end

  def stub_search(status: 200, body:, token: nil)
    stub = stub_request(:post, endpoint)
    stub = stub.with(body: hash_including("pageToken" => token)) if token
    stub.to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  subject(:client) { described_class.new(api_key: api_key, page_delay: 0) }

  describe "#search" do
    it "maps Places JSON into normalized Snapshots (ADR-002)" do
      stub_search(body: page("text_search_page2")) # single page, no nextPageToken

      result = client.search("restaurantes en Curicó, Chile")

      expect(result).to be_success
      snapshot = result.snapshots.first
      expect(snapshot).to have_attributes(
        place_id: "ChIJ_curico_resto_3",
        name: "Restaurant Los Robles",
        address: "Prat 789, Curicó, Maule",
        lat: -34.9840,
        lng: -71.2380,
        phone: "+56 75 220 1122",
        rating: 4.1,
        user_rating_count: 42,
        website_uri: "https://losrobles.cl",
        types: [ "restaurant", "food" ],
        business_status: "CLOSED_TEMPORARILY"
      )
    end

    it "sends the API key and field mask headers, never Place Details (ADR-002)" do
      stub_search(body: page("text_search_page2"))

      client.search("botillerías en Talca, Chile")

      expect(a_request(:post, endpoint).with(
        headers: { "X-Goog-Api-Key" => api_key, "X-Goog-FieldMask" => PlacesClient::FIELD_MASK }
      )).to have_been_made.once
    end

    it "follows nextPageToken and counts one api_call per page (quota counter, ADR-002)" do
      stub_request(:post, endpoint)
        .to_return(
          { status: 200, body: page("text_search_page1"), headers: { "Content-Type" => "application/json" } },
          { status: 200, body: page("text_search_page2"), headers: { "Content-Type" => "application/json" } }
        )

      result = client.search("restaurantes en Curicó, Chile")

      expect(result.snapshots.size).to eq(3)
      expect(result.api_calls).to eq(2)
    end

    it "stops at MAX_PAGES even if Google keeps returning a token (ADR-011 corte de ~60)" do
      always_more = { "places" => [], "nextPageToken" => "loop" }.to_json
      stub_request(:post, endpoint)
        .to_return(status: 200, body: always_more, headers: { "Content-Type" => "application/json" })

      result = described_class.new(api_key: api_key, page_delay: 0, max_pages: 3).search("x")

      expect(result.api_calls).to eq(3)
    end

    it "returns an error result on quota/HTTP failure without raising (SyncJob retries)" do
      stub_search(status: 429, body: '{"error":"RESOURCE_EXHAUSTED"}')

      result = client.search("farmacias en Molina, Chile")

      expect(result).not_to be_success
      expect(result.error).to include("HTTP 429")
      expect(result.snapshots).to be_empty
    end

    it "short-circuits when the API key is absent (no HTTP call)" do
      result = described_class.new(api_key: nil).search("x")

      expect(result).not_to be_success
      expect(result.error).to eq("API key ausente")
      expect(a_request(:post, endpoint)).not_to have_been_made
    end

    it "handles a network timeout gracefully" do
      stub_request(:post, endpoint).to_timeout

      result = client.search("x")

      expect(result).not_to be_success
      expect(result.error).to match(/Timeout|timeout|execution expired/)
    end
  end
end
