# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.6
ARG NODE_MAJOR=20

# ── Shared build toolchain ────────────────────────────────────────────────────
FROM ruby:${RUBY_VERSION}-slim AS build-base
ARG NODE_MAJOR

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    PATH=/usr/local/bundle/bin:$PATH \
    LANG=C.UTF-8

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      pkg-config \
      git \
      curl \
      ca-certificates \
      gnupg \
      libyaml-dev \
      default-libmysqlclient-dev && \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /rails

# ── Development (source bind-mounted at runtime, fat image) ──────────────────
FROM build-base AS development

ENV RAILS_ENV=development

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libyaml-0-2 \
      libjemalloc2 \
      default-mysql-client && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY package.json package-lock.json ./
RUN npm ci && npm cache clean --force

RUN gem install foreman --no-document

EXPOSE 4000
CMD ["bin/dev"]

# ── Staging builder (gems without dev/test + precompile assets) ───────────────
FROM build-base AS staging-builder

ENV BUNDLE_WITHOUT="development:test" \
    RAILS_ENV=staging

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY package.json package-lock.json ./
RUN npm ci && npm cache clean --force

COPY . .

RUN bundle exec bootsnap precompile --gemfile app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile
RUN rm -rf node_modules tmp/cache log/* spec/

# ── Staging runtime (minimal, non-root) ──────────────────────────────────────
FROM ruby:${RUBY_VERSION}-slim AS staging

ENV RAILS_ENV=staging \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" \
    PATH=/usr/local/bundle/bin:$PATH \
    LANG=C.UTF-8 \
    LD_PRELOAD=libjemalloc.so.2 \
    MALLOC_CONF=dirty_decay_ms:1000,narenas:2,background_thread:true \
    RUBY_YJIT_ENABLE=1

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      libyaml-0-2 \
      libjemalloc2 \
      default-mysql-client \
      tini && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

WORKDIR /rails

COPY --from=staging-builder --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=staging-builder --chown=rails:rails /rails /rails

USER 1000:1000

EXPOSE 4000
ENTRYPOINT ["/usr/bin/tini", "--", "bin/docker-entrypoint"]
CMD ["bin/thrust", "bin/rails", "server", "-p", "4000"]
