FROM ruby:3.1.6-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential curl git libpq-dev nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Gemfile, regenerate lock for linux
COPY Gemfile ./
RUN bundle lock --add-platform x86_64-linux && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4

# JS dependencies
COPY package.json package-lock.json* ./
RUN npm ci --production 2>/dev/null || npm install --omit=dev

# App code
COPY . .

# Precompile assets
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=dummy_for_precompile
RUN bundle exec rake assets:precompile 2>/dev/null || true

EXPOSE 10000
ENV PORT=10000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
