require "rails_helper"

RSpec.describe PosCandidateClassifier do
  def classify(types) = described_class.call(types)

  it "es candidato cuando algún type está en la lista objetivo (ADR-004)" do
    expect(classify([ "restaurant", "food", "point_of_interest" ])).to be(true)
    expect(classify([ "liquor_store" ])).to be(true)
    expect(classify([ "pharmacy", "health" ])).to be(true)
  end

  it "no es candidato cuando ningún type está en la lista" do
    expect(classify([ "hair_care", "beauty_salon" ])).to be(false)
    expect(classify([ "hardware_store" ])).to be(false)
  end

  it "maneja types vacío o nil" do
    expect(classify([])).to be(false)
    expect(classify(nil)).to be(false)
  end
end
