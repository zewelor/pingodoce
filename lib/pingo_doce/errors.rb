# frozen_string_literal: true

module PingoDoce
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class APIError < Error; end
  class ConfigurationError < Error; end
  class NotAuthenticatedError < AuthenticationError; end
  class DatabaseError < Error; end
  class StorageError < Error; end
end
