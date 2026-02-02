class BoxSyncService
  SUPPORTED_EXTENSIONS = %w[.pdf .png .jpg .jpeg].freeze

  def initialize(company, user, sync_job)
    @company = company
    @user = user
    @sync_job = sync_job
  end

  def run
    @sync_job.update!(status: 'scanning', started_at: Time.current)

    token = @company.box_developer_token
    folder_id = @company.box_folder_id
    unless token.present? && folder_id.present?
      return fail_job('Box developer token and folder ID are required')
    end

    client = Boxr::Client.new(token)

    # Recursively collect all supported files
    files = collect_files(client, folder_id)
    @sync_job.update!(total_files: files.size, status: 'importing')

    files.each_with_index do |file_info, idx|
      @sync_job.update!(current_file: file_info[:name], processed_files: idx)
      process_file(client, file_info)
    end

    @sync_job.update!(
      status: 'completed',
      processed_files: files.size,
      current_file: nil,
      completed_at: Time.current
    )
  rescue Boxr::BoxrError => e
    fail_job("Box API error: #{e.message}")
  rescue => e
    fail_job("Unexpected error: #{e.message}")
  end

  private

  def collect_files(client, folder_id, path = '')
    files = []
    items = client.folder_items(folder_id, fields: [:name, :type, :id])

    items.each do |item|
      if item.type == 'folder'
        subfolder_path = path.present? ? "#{path}/#{item.name}" : item.name
        files.concat(collect_files(client, item.id, subfolder_path))
      elsif item.type == 'file' && supported_file?(item.name)
        files << { id: item.id, name: item.name, path: path }
      end
    end

    files
  end

  def supported_file?(filename)
    ext = File.extname(filename).downcase
    SUPPORTED_EXTENSIONS.include?(ext)
  end

  def process_file(client, file_info)
    # Skip if already imported
    if @company.box_imported_files.exists?(box_file_id: file_info[:id].to_s)
      @sync_job.increment!(:skipped_files)
      return
    end

    # Download file content
    content = client.download_file(file_info[:id])
    filename = file_info[:name]

    # Process via StatementProcessingService
    result = StatementProcessingService.new(@company, @user).process(
      file_content: content,
      filename: filename
    )

    upload_id = result.dig(:steps, :import, :upload_id)

    if result[:success] || result[:partial]
      @company.box_imported_files.create!(
        box_file_id: file_info[:id].to_s,
        filename: filename,
        box_folder_path: file_info[:path],
        statement_upload_id: upload_id,
        status: 'imported'
      )
      @sync_job.increment!(:imported_files)
    else
      error_msg = result[:errors]&.join('; ') || 'Processing failed'
      @company.box_imported_files.create!(
        box_file_id: file_info[:id].to_s,
        filename: filename,
        box_folder_path: file_info[:path],
        status: 'failed',
        error_message: error_msg
      )
      @sync_job.increment!(:failed_files)
    end
  rescue => e
    @company.box_imported_files.create!(
      box_file_id: file_info[:id].to_s,
      filename: file_info[:name],
      box_folder_path: file_info[:path],
      status: 'failed',
      error_message: e.message
    )
    @sync_job.increment!(:failed_files)
  end

  def fail_job(message)
    @sync_job.update!(
      status: 'failed',
      error_message: message,
      completed_at: Time.current
    )
  end
end
