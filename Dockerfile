ARG RUBY_VERSION=3.1.6
FROM ruby:${RUBY_VERSION}-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential curl git libpq-dev nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment true && \
    bundle config set --local without 'development test' && \
    bundle install

# JS dependencies
COPY package.json package-lock.json ./
RUN npm ci || npm install

# App code
COPY . .

# Precompile assets
RUN SECRET_KEY_BASE=dummy bundle exec rake assets:precompile

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
