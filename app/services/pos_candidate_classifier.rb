# Calcula pos_candidate (ADR-004) desde los `types` de Places contra la lista
# configurable de rubros-objetivo (config/oteo.yml → pos_candidate_types).
#
# La heurística pre-filtra a quién preguntar; el dato observado en terreno
# (pos_status) manda sobre esta columna. Separar lo inferido de lo observado
# mantiene el pipeline honesto.
class PosCandidateClassifier
  def self.call(types)
    new(types).call
  end

  def initialize(types)
    @types = Array(types).map(&:to_s)
  end

  def call
    (@types & target_types).any?
  end

  private

  def target_types = Rails.configuration.oteo.pos_candidate_types
end
