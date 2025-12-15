# frozen_string_literal: true

require "logger"

module PingoDoce
  class Configuration
    attr_accessor :phone_number, :password, :data_dir, :timeout, :logger

    DEFAULT_TIMEOUT = 15
    DEFAULT_DATA_DIR = "data"

    def initialize
      @phone_number = ENV.fetch("PHONE_NUMBER", nil)
      @password = ENV.fetch("PASSWORD", nil)
      @data_dir = ENV.fetch("DATA_DIR", DEFAULT_DATA_DIR)
      @timeout = ENV.fetch("TIMEOUT", DEFAULT_TIMEOUT).to_i
      @logger = build_logger
    end

    def validate!
      raise AuthenticationError, credentials_error if invalid_credentials?
    end

    private

    def build_logger
      Logger.new($stdout).tap do |log|
        log.level = log_level
        log.formatter = proc { |severity, _datetime, _progname, msg| "[#{severity}] #{msg}\n" }
      end
    end

    def log_level
      case ENV.fetch("LOG_LEVEL", "info").downcase
      when "debug" then Logger::DEBUG
      when "warn" then Logger::WARN
      when "error" then Logger::ERROR
      else Logger::INFO
      end
    end

    def invalid_credentials?
      phone_number.nil? || phone_number == "+351..." ||
        password.nil? || password.empty?
    end

    def credentials_error
      <<~MSG
        Please set PHONE_NUMBER and PASSWORD in your .env file
        Example:
          PHONE_NUMBER=+351123456789
          PASSWORD=your_password
      MSG
    end
  end
end
