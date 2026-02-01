source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# ruby '3.1.6'

gem 'rails', '~> 6.1'
gem 'pg', '~> 1.1'
gem 'puma', '~> 5.0'
gem 'sass-rails', '>= 6'
gem 'webpacker', '~> 5.0'
gem 'turbolinks', '~> 5'
gem 'jbuilder', '~> 2.7'
gem 'bootsnap', '>= 1.4.4', require: false
gem 'listen', '~> 3.3'

# Authentication
gem 'devise'

# JWT for API auth
gem 'jwt'

# Plaid integration
gem 'plaid', '~> 29.0'

# PDF generation for reports
gem 'wicked_pdf'
gem 'wkhtmltopdf-binary'

# Charts
gem 'chartkick'

# Background jobs
gem 'sidekiq'

# Pagination
gem 'kaminari'

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'dotenv-rails'
end

group :development do
  gem 'web-console', '>= 4.1.0'
  gem 'spring'
end
