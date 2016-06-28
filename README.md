# ServerHealthCheck

This gem provides a standard set of health checks for web services

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'server_health_check'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install server_health_check

## Usage

```ruby
class SomeController
  def show
    health_check = ServerHealthCheck.new
    health_check.active_record!
    health_check.redis!(host: 'optional', port: 1234)
    health_check.aws_s3!(bucket: 'yakmail-inbound')
    health_check.check! do
      # app-specific code that wouldn't belong in the gem
      # return true or false
    end
    http_status = health_check.ok? ? 200 : 500
    render status: http_status, json: {status: health_check.results}
  end
end
```

## Development
Run rake to run tests before committing code
