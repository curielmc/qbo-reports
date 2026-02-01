FROM ruby:3.1.6-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential curl git libpq-dev && \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install --no-install-recommends -y nodejs && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gems
COPY Gemfile ./
RUN bundle lock --add-platform x86_64-linux && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4

# JS dependencies (webpacker needs yarn)
COPY package.json yarn.lock* package-lock.json* ./
RUN if [ -f yarn.lock ]; then yarn install; elif [ -f package-lock.json ]; then npm ci; else npm install; fi

# App code
COPY . .

# Precompile assets (webpacker + sprockets)
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=dummy_for_precompile
ENV NODE_ENV=production
RUN bundle exec rails webpacker:compile
RUN bundle exec rails assets:precompile

EXPOSE 10000
ENV PORT=10000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
