# frozen_string_literal: true

require "bundler/setup"
Bundler.require(:default)

require "zeitwerk"

module PingoDoce
  class << self
    def loader
      @loader ||= Zeitwerk::Loader.for_gem.tap do |loader|
        loader.setup
      end
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def logger
      configuration.logger
    end

    def reset_configuration!
      @configuration = nil
    end
  end
end

PingoDoce.loader
