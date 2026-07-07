require "rails_helper"

RSpec.describe LeadScorer do
  def score(count:, presence:, pos: false)
    described_class.call(user_rating_count: count, digital_presence: presence, pos_candidate: pos)
  end

  it "un negocio sin reseñas da score 0 (va a la vista 'nuevos' — ADR-008)" do
    expect(score(count: 0, presence: "sin_presencia", pos: true)).to eq(0)
  end

  it "web_propia da score 0: no es lead para vender web (peso 0)" do
    expect(score(count: 500, presence: "web_propia", pos: true)).to eq(0)
  end

  it "premia reputación alta + sin presencia (el lead ideal)" do
    expect(score(count: 213, presence: "sin_presencia", pos: true)).to be_within(0.001).of(6.707)
  end

  it "aplica el bonus POS solo cuando pos_candidate" do
    con_bonus = score(count: 100, presence: "sin_presencia", pos: true)
    sin_bonus = score(count: 100, presence: "sin_presencia", pos: false)
    expect(con_bonus).to be > sin_bonus
    expect(con_bonus / sin_bonus).to be_within(0.001).of(1.25)
  end

  it "ordena sin_presencia > solo_redes a igual reputación (guiones de venta distintos)" do
    expect(score(count: 100, presence: "sin_presencia")).to be > score(count: 100, presence: "solo_redes")
  end

  it "clasificación ausente (nil) da score 0 sin romper" do
    expect(score(count: 100, presence: nil)).to eq(0)
  end
end
