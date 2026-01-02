# syntax=docker/dockerfile:1

ARG RUBY_VERSION=4.0
FROM ruby:${RUBY_VERSION}-alpine AS base

ENV BUNDLE_PATH=/bundle
ENV BUNDLE_WITHOUT=

RUN gem update --system && gem install bundler:2.5.0

# Runtime packages for SQLite
RUN apk add --no-cache sqlite-libs

WORKDIR /app

# Development stage
FROM base AS dev

# Build packages including SQLite dev libraries
RUN apk add --no-cache build-base git yaml-dev sqlite-dev

RUN mkdir -p /bundle && chmod 777 /bundle

# CI stage
FROM base AS ci

RUN apk add --no-cache build-base git yaml-dev sqlite-dev

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local jobs "$(nproc)" && \
    bundle config set --local retry 3 && \
    bundle install && \
    rm -rf /bundle/cache/*.gem && \
    find /bundle -name "*.git" -type d -exec rm -rf {} + 2>/dev/null || true

COPY . .

# Live builder stage
FROM base AS live_builder

RUN apk add --no-cache build-base git yaml-dev sqlite-dev

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local jobs "$(nproc)" && \
    bundle config set --local retry 3 && \
    bundle config set --local without "development test" && \
    bundle install && \
    rm -rf /bundle/cache/*.gem && \
    find /bundle -name "*.git" -type d -exec rm -rf {} + 2>/dev/null || true

# Production stage
FROM base AS live

ENV BUNDLE_DEPLOYMENT=true
ENV RUBYOPT="--disable-did_you_mean"

COPY --from=live_builder /bundle /bundle
COPY . .

RUN chmod +x bin/cli && \
    apk add --no-cache catatonit

ENTRYPOINT ["/usr/bin/catatonit", "--"]
CMD ["bin/cli"]
