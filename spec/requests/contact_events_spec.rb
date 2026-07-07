require "rails_helper"

RSpec.describe "ContactEvents", type: :request do
  let(:user) { create(:user) }
  let(:business) { create(:business) }

  before { sign_in(user) }

  describe "POST /businesses/:business_id/contact_events" do
    it "crea un evento y responde con turbo_stream" do
      expect {
        post business_contact_events_path(business),
             params: { contact_event: { event_type: "llamada", product: "web", body: "Volver a llamar el lunes" } },
             as: :turbo_stream
      }.to change { business.contact_events.count }.by(1)

      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include("Volver a llamar el lunes")
    end

    it "no crea un evento sin event_type y responde 422" do
      post business_contact_events_path(business),
           params: { contact_event: { event_type: "", body: "x" } },
           as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
