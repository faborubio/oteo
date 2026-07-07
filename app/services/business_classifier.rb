# Aplica los tres clasificadores a un Business en memoria (no guarda: el SyncJob
# persiste). Orden importa: la presencia digital alimenta el lead_score.
#
# NUNCA toca campos manuales (pos_status, pos_vendor, pipeline_stage): la clasificación
# es dato inferido; el terreno es dato observado y manda (ADR-004).
class BusinessClassifier
  def self.classify(business)
    new(business).classify
  end

  def initialize(business)
    @business = business
  end

  def classify
    business.digital_presence = PresenceClassifier.call(business.website_uri)
    business.pos_candidate = PosCandidateClassifier.call(business.types)
    business.lead_score = LeadScorer.call(
      user_rating_count: business.user_rating_count,
      digital_presence: business.digital_presence,
      pos_candidate: business.pos_candidate
    )
    business
  end

  private

  attr_reader :business
end
