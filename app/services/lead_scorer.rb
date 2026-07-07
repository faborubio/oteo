# Calcula el lead_score (ADR-008): reputación × ausencia de presencia × bonus POS.
#
#   score = log(1 + user_rating_count) * peso_presencia * bonus_pos
#
# Fórmula legible a propósito: se valida empíricamente (¿los de arriba convierten?)
# y los pesos se ajustan con esa evidencia (config/oteo.yml). Un negocio con 0 reseñas
# da score 0 y va a la vista "nuevos/sin reputación", no al fondo del ranking.
class LeadScorer
  def self.call(user_rating_count:, digital_presence:, pos_candidate:)
    new(user_rating_count:, digital_presence:, pos_candidate:).call
  end

  def initialize(user_rating_count:, digital_presence:, pos_candidate:)
    @user_rating_count = user_rating_count.to_i
    @digital_presence = digital_presence
    @pos_candidate = pos_candidate
  end

  def call
    reputation = Math.log(1 + [ @user_rating_count, 0 ].max)
    (reputation * presence_weight * pos_bonus).round(3)
  end

  private

  def presence_weight
    weights = Rails.configuration.oteo.lead_score[:presence_weights]
    weights.fetch(@digital_presence&.to_sym, 0).to_f
  end

  def pos_bonus
    return 1.0 unless @pos_candidate

    Rails.configuration.oteo.lead_score[:pos_candidate_bonus].to_f
  end
end
