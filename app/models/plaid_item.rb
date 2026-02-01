class PlaidItem < ApplicationRecord
  belongs_to :company
  has_many :accounts, dependent: :nullify

  encrypts :access_token

  validates :access_token, presence: true
  validates :item_id, presence: true, uniqueness: true
  validates :status, presence: true

  scope :active, -> { where(status: 'active') }
  scope :needs_reauth, -> { where(status: 'needs_reauth') }

  def active?
    status == 'active'
  end

  def needs_reauth?
    status == 'needs_reauth'
  end
end
