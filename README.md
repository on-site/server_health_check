# ServerHealthCheck

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/server_health_check`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

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

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/server_health_check.
