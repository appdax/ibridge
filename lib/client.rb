require 'mongo'
require 'logger'

# Base class for Importer and Unifier with some common logic
# and a shared mongo client instance.
class Client
  # Options used for bulk operations
  OPTS = { write_concern: { w: 0 },
           ordered: false,
           bypass_document_validation: true }.freeze

  private_constant :OPTS

  # Logger instance for mongo client.
  #
  # @return [ Logger ]
  def self.logger
    FileUtils.mkdir_p 'log'
    file = File.open('log/mongo.log', File::WRONLY | File::APPEND | File::CREAT)
    @@logger ||= Logger.new(file) # rubocop:disable Style/ClassVars
  end

  # Client instance to connect to the Mongo DB.
  #
  # @return [ Mongo::Client ]
  def self.connection
    @@client ||= begin # rubocop:disable Style/ClassVars
      Mongo::Logger.logger = logger
      Mongo::Logger.logger.level = Logger::INFO
      Mongo::Client.new ENV['MONGO_URI']
    end
  end

  class << self
    # protected :connection
    # protected :logger
  end

  # Initializes the instance and sets all default values.
  #
  # @param [ Int ] batch_size Specifies the size of each batch of documents
  #                           the cursor will return on each GETMORE operation.
  #                           Defaults to: 500
  #
  # @return [ Client ]
  def initialize(batch_size: 500)
    batch_size(batch_size)
  end

  # Specifies the size of each batch of documents
  # the cursor will returnon each GETMORE operation.
  #
  # @exmple Get the value.
  #   batch_size
  #   # => 500
  #
  # @example Set the value.
  #   batch_size(250)
  #   # => self
  #
  # @param [ Int] value The value to set for.
  #
  # @return [ Int ]
  def batch_size(value = nil)
    @batch_size = [1, value.to_i].max unless value.nil?
    @batch_size ||= 500
    value.nil? ? @batch_size : self
  end

  protected

  # Client instance to connect to the Mongo DB.
  #
  # @return [ Mongo::Client ]
  def client
    self.class.connection
  end
end
