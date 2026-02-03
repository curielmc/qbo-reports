module BoxAuth
  # Build a Boxr::Client using JWT (server-to-server) auth from Rails credentials + private key file.
  # Falls back to ENV vars if credentials aren't present.
  def self.jwt_client
    client_id  = Rails.application.credentials.dig(:box, :client_id)  || ENV['BOX_CLIENT_ID']
    secret     = Rails.application.credentials.dig(:box, :client_secret) || ENV['BOX_CLIENT_SECRET']
    enterprise = Rails.application.credentials.dig(:box, :enterprise_id) || ENV['BOX_ENTERPRISE_ID']
    key_id     = Rails.application.credentials.dig(:box, :public_key_id) || ENV['BOX_PUBLIC_KEY_ID']
    passphrase = Rails.application.credentials.dig(:box, :private_key_passphrase) || ENV['BOX_PRIVATE_KEY_PASSPHRASE']

    key_path = Rails.root.join('config', 'box_private_key.pem')
    private_key = if File.exist?(key_path)
                    File.read(key_path)
                  elsif ENV['BOX_PRIVATE_KEY'].present?
                    ENV['BOX_PRIVATE_KEY'].gsub('\n', "\n")
                  else
                    raise "Box private key not found. Set BOX_PRIVATE_KEY env var or place config/box_private_key.pem"
                  end

    Boxr::Client.new(
      '',
      client_id: client_id,
      client_secret: secret,
      enterprise_id: enterprise,
      jwt_private_key: private_key,
      jwt_private_key_password: passphrase,
      jwt_public_key_id: key_id
    )
  end

  # Build a client from a developer token (per-company setting in the UI).
  def self.token_client(token)
    Boxr::Client.new(token)
  end

  # Returns the best available client for a company:
  #   1. Per-company developer token (if set)
  #   2. JWT server auth (if configured)
  def self.client_for(company)
    if company.box_developer_token.present?
      token_client(company.box_developer_token)
    else
      jwt_client
    end
  end

  def self.configured?
    (Rails.application.credentials.dig(:box, :client_id) || ENV['BOX_CLIENT_ID']).present?
  end
end
