ARG RUBY_VERSION=3.1.6
FROM ruby:${RUBY_VERSION}-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential curl git libpq-dev nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gems — add linux platform and install
COPY Gemfile Gemfile.lock ./
RUN bundle lock --add-platform x86_64-linux && \
    bundle config set --local without 'development test' && \
    bundle install

# JS dependencies
COPY package.json package-lock.json* ./
RUN npm ci --production 2>/dev/null || npm install --production

# App code
COPY . .

# Precompile assets
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=dummy_for_precompile
RUN bundle exec rake assets:precompile

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
