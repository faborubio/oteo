class Rubro < ApplicationRecord
  has_many :business_rubros, dependent: :destroy
  has_many :businesses, through: :business_rubros
  has_many :sync_runs, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :label, presence: true
  validates :text_search_query, presence: true

  scope :active, -> { where(active: true) }
  scope :pos_targets, -> { where(pos_target: true) }
end
