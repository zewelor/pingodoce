# frozen_string_literal: true

require "sequel"
require "fileutils"

module PingoDoce
  class Database
    class << self
      def connection
        @connection ||= connect!
      end

      def setup!
        DatabaseSetup.run(connection)
      end

      def disconnect
        @connection&.disconnect
        @connection = nil
      end

      alias_method :reset!, :disconnect

      private

      def connect!
        ensure_data_dir_exists

        url = PingoDoce.configuration.database_url
        db = Sequel.connect(url)
        db.loggers << PingoDoce.logger if ENV["LOG_LEVEL"] == "debug"
        db
      rescue Sequel::DatabaseConnectionError => e
        raise DatabaseError, "Failed to connect to database: #{e.message}"
      end

      def ensure_data_dir_exists
        data_dir = PingoDoce.configuration.data_dir
        FileUtils.mkdir_p(data_dir)
      end
    end
  end
end
