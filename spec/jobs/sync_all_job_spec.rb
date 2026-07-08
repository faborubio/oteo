require "rails_helper"

RSpec.describe SyncAllJob, type: :job do
  it "encola un SyncJob por cada combinación activa comuna × rubro" do
    c1 = create(:comuna); c2 = create(:comuna)
    r1 = create(:rubro); r2 = create(:rubro)
    create(:comuna, active: false) # inactiva: no se encola
    create(:rubro, active: false)

    expect { described_class.perform_now }
      .to have_enqueued_job(SyncJob).exactly(4).times # 2 comunas × 2 rubros activos

    expect(SyncJob).to have_been_enqueued.with(c1.id, r1.id)
    expect(SyncJob).to have_been_enqueued.with(c2.id, r2.id)
  end
end
