class BusinessRubro < ApplicationRecord
  belongs_to :business
  belongs_to :rubro

  validates :rubro_id, uniqueness: { scope: :business_id }
end
