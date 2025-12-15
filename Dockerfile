# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.3
FROM ruby:${RUBY_VERSION}-alpine AS base

ENV BUNDLE_PATH=/bundle
ENV BUNDLE_WITHOUT=

RUN gem update --system && gem install bundler:2.5.0

ARG RUNTIME_PACKAGES=""
RUN apk add --no-cache ${RUNTIME_PACKAGES}

WORKDIR /app

# Development stage
FROM base AS dev

ARG DEV_PACKAGES="build-base git yaml-dev"
RUN apk add --no-cache ${DEV_PACKAGES}

RUN mkdir -p /bundle && chown -R nobody:nobody /bundle

# CI stage
FROM base AS ci

ARG DEV_PACKAGES="build-base git yaml-dev"
RUN apk add --no-cache ${DEV_PACKAGES}

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local jobs $(nproc) && \
    bundle config set --local retry 3 && \
    bundle install && \
    rm -rf /bundle/cache/*.gem && \
    find /bundle -name "*.git" -type d -exec rm -rf {} + 2>/dev/null || true

COPY . .

# Live builder stage
FROM base AS live_builder

ARG DEV_PACKAGES="build-base git yaml-dev"
RUN apk add --no-cache ${DEV_PACKAGES}

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local jobs $(nproc) && \
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

RUN chmod +x bin/cli

RUN apk add --no-cache catatonit

ENTRYPOINT ["/usr/bin/catatonit", "--"]
CMD ["bin/cli"]
