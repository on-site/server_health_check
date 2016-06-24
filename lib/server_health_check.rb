require "server_health_check/version"

class ServerHealthCheck
  def initialize
    @checks = {}
  end
  def redis!(redis_host: nil, port: 6379)
    redis_host ||= ENV['REDIS_HOST'] || 'localhost'
    @checks[:redis] = false
    redis = Redis.new(:host => redis_host, :port => port)
    begin
      redis.ping
      @checks[:redis] = true
      true
    rescue Redis::CannotConnectError
      false
    end
  end

  def ok?
    @checks.all? do |key, value|
      value == true
    end
  end
  
end
