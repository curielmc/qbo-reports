class StatementUpload < ApplicationRecord
  belongs_to :company
  belongs_to :account, optional: true
  belongs_to :user

  validates :filename, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def parsed_transactions
    raw_data['transactions'] || []
  end
end
