require "server_health_check/version"

class ServerHealthCheck
  OK = 'OK'.freeze
  attr_reader :logger

  def initialize(options = {})
    @logger = options[:logger]
    @results = {}
  end

  def redis!(host: nil, port: 6379)
    host ||= ENV['REDIS_HOST'] || 'localhost'
    @results[:redis] = 'The Redis gem is not loaded'
    redis = Redis.new(host: host, port: port)
    begin
      redis.ping
      @results[:redis] = OK
      true
    rescue Redis::CannotConnectError => e
      @results[:redis] = e.to_s
      false
    end
  end

  def active_record!
    begin
      if ActiveRecord::Base.connection_pool.with_connection { |connection| connection.active? }
        @results[:active_record] = OK
        true
      else
        @results[:active_record] = "Failed: unable to connect to database"
        false
      end
    rescue NameError
      raise
    rescue StandardError => e
      @results[:active_record] = "Failed: error while connecting to database"
      false
    end
  end

  def aws_s3!(bucket = nil)
    options = {}
    options[:logger] = logger if logger
    bucket = Aws::S3::Bucket.new(bucket, options)
    if bucket.exists?
      @results[:S3] = OK
      true
    else
      @results[:S3] = "Failed: bucket does not exists"
      false
    end
  end

  def aws_creds!
    options = {}
    options[:logger] = logger if logger
    aws = Aws::S3::Client.new(options)
    begin
      aws.list_buckets
      @results[:AWS] = OK
      true
    rescue Aws::S3::Errors::InvalidAccessKeyId, Aws::S3::Errors::SignatureDoesNotMatch, NoMethodError => e
      @results[:AWS] = e.to_s
      false
    end
  end

  def check!(name = 'custom_check')
    success = yield
    if success
      @results[name.to_sym] = OK
      true
    else
      @results[name.to_sym] = "Failed"
      false
    end
  rescue => e
    @results[name.to_sym] = e.to_s
  end

  def ok?
    @results.all? do |key, value|
      value == OK
    end
  end

  attr_reader :results
end
