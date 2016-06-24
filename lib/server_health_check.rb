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

  def ok?
    @results.all? do |key, value|
      value == OK
    end
  end

  def results
    @results
  end
end
