class BoxImportedFile < ApplicationRecord
  belongs_to :company
  belongs_to :statement_upload, optional: true

  validates :box_file_id, presence: true, uniqueness: { scope: :company_id }

  scope :imported, -> { where(status: 'imported') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(created_at: :desc) }
end
