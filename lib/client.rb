require 'mongo'

# Base class for Importer and Unifier with some common logic
# and a shared mongo client instance.
class Client
  # Options used for bulk operations
  OPTS = { write_concern: { w: 0 },
           ordered: false,
           bypass_document_validation: true }.freeze

  private_constant :OPTS

  # Client instance to connect to the Mongo DB.
  #
  # @return [ Mongo::Client ]
  def self.connection
    @@client ||= Mongo::Client.new ENV['MONGO_URI'] # rubocop:disable Style/ClassVars,Metrics/LineLength
  end

  class << self
    protected_methods :connection
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
    @batch_size = value.to_i unless value.nil?
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
