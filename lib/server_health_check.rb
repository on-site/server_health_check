require "server_health_check/version"

class ServerHealthCheck
  def redis!(redis_host: nil, port: 6379)
    redis_host ||= ENV['REDIS_HOST'] || 'localhost'
    redis = Redis.new(:host => redis_host, :port => port)
    begin
      redis.ping
      true
    rescue Redis::CannotConnectError
      false
    end
  end
end
