require "server_health_check/version"

class ServerHealthCheck
  OK = 'OK'

  def initialize
    @results = {}
  end

  def redis!(host: nil, port: 6379)
    host ||= ENV['REDIS_HOST'] || 'localhost'
    @results[:redis] = 'The Redis gem is not loaded'
    redis = Redis.new(:host => host, :port => port)
    begin
      redis.ping
      @results[:redis] = OK
      true
    rescue Redis::CannotConnectError => e
      @results[:redis] = e.to_s
      false
    end
  end

  def active_record!()
    if ActiveRecord::Base.connected?
      @results[:database] = "OK"
      true
    else
      @results[:database] = "Failed: unable to connect to database"
      false
    end
  end

  def aws_s3!(bucket=nil)
     bucket = Aws::S3::Bucket.new(bucket)
     if bucket.exists?
       @results[:S3] = "OK"
       true
     else
       @results[:S3] = "Failed: bucket does not exist"
       false
     end
  end

  def aws_creds!
    aws = Aws::S3::Client.new
    begin
      aws.list_buckets
      @results[:AWS] = "OK"
      true
    rescue Aws::S3::Errors::InvalidAccessKeyId, Aws::S3::Errors::SignatureDoesNotMatch, NoMethodError => e
      @results[:AWS] = e.to_s
      false
    end
  end

  def check!
    success = yield
    if success
      @results[:check] = "OK"
      true
    else
      @results[:check] = "Failed"
      false
    end
    rescue => e
      @results[:check] = e.to_s    
  end

  def ok?
    @results.all? do |key, value|
      value == OK
    end
  end

  def results
    @results
  end
end
