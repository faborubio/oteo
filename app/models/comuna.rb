class Comuna < ApplicationRecord
  has_many :businesses, dependent: :restrict_with_error
  has_many :sync_runs, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :region, presence: true

  scope :active, -> { where(active: true) }
end
