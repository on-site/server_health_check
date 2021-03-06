require 'spec_helper'

module ActiveRecord
  class ConnectionPool
    def with_connection
      yield ActiveRecord::Base.connection
    end
  end

  class Connection
    def active?
      raise "This method should be stubbed"
    end
  end

  class Base
    def self.connection_pool
      @connection_pool ||= ActiveRecord::ConnectionPool.new
    end

    def self.connection
      @connection ||= ActiveRecord::Connection.new
    end
  end
end

class Redis
  class CannotConnectError < StandardError; end
  def initialize(options = nil); end
end

module Aws
  class S3
    class Bucket
      def initialize(bucket_name, options = nil); end
    end

    class Client
      def initialize(options = nil); end
    end

    class Errors
      class SignatureDoesNotMatch < StandardError; end
      class InvalidAccessKeyId < StandardError; end
    end
  end
end

describe ServerHealthCheck do
  it 'has a version number' do
    expect(ServerHealthCheck::VERSION).not_to be nil
  end

  describe 'typical use case' do
    context 'when all is well' do
      before do
        allow_any_instance_of(Redis).to receive(:ping).and_return(true)
        allow(ActiveRecord::Base.connection).to receive(:active?).and_return(true)
        allow_any_instance_of(Aws::S3::Bucket).to receive(:exists?).and_return(true)
        allow_any_instance_of(Aws::S3::Client).to receive(:list_buckets).and_return(true)
      end

      it 'reports OK' do
        health_check = ServerHealthCheck.new
        health_check.active_record!
        health_check.redis!(host: 'optional', port: 1234)
        health_check.aws_s3!(bucket: 'yakmail-inbound')
        health_check.aws_creds!
        health_check.check! { 1 + 2 }
        http_status = health_check.ok? ? 200 : 500
        expect(http_status).to eq 200
        expect(health_check.results.keys).to contain_exactly(
          :active_record,
          :redis,
          :S3,
          :AWS,
          :custom_check
        )
        expect(health_check.results.values).to all eq('OK')
      end
    end

    context 'when only one check fails' do
      before do
        allow_any_instance_of(Redis).to receive(:ping).and_raise(Redis::CannotConnectError)
        connection_double = double
        allow(ActiveRecord::Base.connection).to receive(:active?).and_raise(StandardError.new("DB error"))
        allow_any_instance_of(Aws::S3::Bucket).to receive(:exists?).and_return(true)
        allow_any_instance_of(Aws::S3::Client).to receive(:list_buckets).and_return(true)
      end

      it 'reports failure' do
        health_check = ServerHealthCheck.new
        health_check.active_record!
        health_check.redis!(host: 'optional', port: 1234)
        health_check.aws_s3!(bucket: 'yakmail-inbound')
        health_check.aws_creds!
        health_check.check! { true }
        http_status = health_check.ok? ? 200 : 500
        expect(http_status).to eq 500
        expect(health_check.results.keys).to contain_exactly(
          :active_record,
          :redis,
          :S3,
          :AWS,
          :custom_check
        )
        expect(health_check.results.values).to include 'Redis::CannotConnectError'
      end
    end
  end

  let(:health_check) { ServerHealthCheck.new }

  describe "#redis!" do
    context "when redis gem is not loaded" do
      before do
        hide_const("Redis")
      end

      it 'raises an execpetion' do
        expect { health_check.redis! }.to raise_error(NameError, /Redis/)
      end

      describe "#ok?" do
        it 'returns false' do
          health_check.redis! rescue true
          expect(health_check.ok?).to eq false
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.redis! rescue true
          results = health_check.results
          expect(results).to eq redis: 'The Redis gem is not loaded'
        end
      end
    end

    context "when redis is not reachable" do
      before do
        allow_any_instance_of(Redis).to receive(:ping).and_raise(Redis::CannotConnectError)
      end

      it 'returns false' do
        expect(health_check.redis!).to eq false
      end

      describe "#ok?" do
        it 'returns false' do
          health_check.redis!
          expect(health_check.ok?).to eq false
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.redis!
          results = health_check.results
          expect(results).to eq redis: 'Redis::CannotConnectError'
        end
      end
    end

    context "when redis is connected" do
      before do
        allow_any_instance_of(Redis).to receive(:ping).and_return(true)
      end

      it 'returns true' do
        expect(health_check.redis!).to eq true
      end

      describe "#ok?" do
        it 'returns true' do
          health_check.redis!
          expect(health_check.ok?).to eq true
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.redis!
          results = health_check.results
          expect(results).to eq redis: 'OK'
        end
      end
    end
  end

  describe "#active_record!" do
    context "when Active Record gem is not loaded" do
      before do
        hide_const("ActiveRecord")
      end

      it 'raises an execpetion' do
        expect { health_check.active_record! }.to raise_error(NameError, /ActiveRecord/)
      end
    end

    context "when database is not reachable" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:active?).and_raise(StandardError.new("DB: error"))
      end

      it 'returns false' do
        expect(health_check.active_record!).to eq false
      end

      describe "#ok?" do
        it 'returns false' do
          health_check.active_record!
          expect(health_check.ok?).to eq false
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.active_record!
          results = health_check.results
          expect(results).to eq active_record: 'Failed: error while connecting to database'
        end
      end
    end

    context "when database connection is not active when retrieved" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:active?).and_return(false)
      end

      it "returns false" do
        expect(health_check.active_record!).to eq false
      end

      describe "#ok?" do
        it "returns false" do
          health_check.active_record!
          expect(health_check.ok?).to eq false
        end
      end

      describe "#results" do
        it "returns a hash with string results" do
          health_check.active_record!
          results = health_check.results
          expect(results).to eq active_record: "Failed: unable to connect to database"
        end
      end
    end

    context "when database is reachable" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:active?).and_return(true)
      end

      it 'returns true' do
        expect(health_check.active_record!).to eq true
      end

      describe "#ok?" do
        it 'returns true' do
          health_check.active_record!
          expect(health_check.ok?).to eq true
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.active_record!
          results = health_check.results
          expect(results).to eq active_record: 'OK'
        end
      end
    end
  end

  describe "#aws_s3!" do
    context "when aws-sdk gem is not loaded" do
      before do
        hide_const("Aws")
      end

      it 'raises an execpetion' do
        expect { health_check.aws_s3!('test-bucket') }.to raise_error(NameError, /Aws/)
      end
    end

    context "when bucket does not exist" do
      before do
        allow_any_instance_of(Aws::S3::Bucket).to receive(:exists?).and_return(false)
      end

      it 'returns false' do
        expect(health_check.aws_s3!('test-bucket')).to eq false
      end

      describe "#ok?" do
        it 'returns false' do
          health_check.aws_s3!('test-bucket')
          expect(health_check.ok?).to eq false
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.aws_s3!('test-bucket')
          results = health_check.results
          expect(results).to eq S3: 'Failed: bucket does not exists'
        end
      end
    end

    context "when bucket exist" do
      before do
        allow_any_instance_of(Aws::S3::Bucket).to receive(:exists?).and_return(true)
      end

      it 'returns true' do
        expect(health_check.aws_s3!('test-bucket')).to eq true
      end

      describe "#ok?" do
        it 'returns true' do
          health_check.aws_s3!('test-bucket')
          expect(health_check.ok?).to eq true
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.aws_s3!('test-bucket')
          results = health_check.results
          expect(results).to eq S3: 'OK'
        end
      end
    end
  end

  describe "#aws_creds!" do
    context "when aws-sdk gem is not loaded" do
      before do
        hide_const("Aws")
      end

      it 'raises an execpetion' do
        expect { health_check.aws_creds! }.to raise_error(NameError, /Aws/)
      end
    end

    context "when access key is invalid" do
      before do
        allow_any_instance_of(Aws::S3::Client).to receive(:list_buckets).and_raise(Aws::S3::Errors::InvalidAccessKeyId)
      end

      it 'returns false' do
        expect(health_check.aws_creds!).to eq false
      end

      describe "#ok?" do
        it 'returns false' do
          health_check.aws_creds!
          expect(health_check.ok?).to eq false
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.aws_creds!
          results = health_check.results
          expect(results).to eq AWS: 'Aws::S3::Errors::InvalidAccessKeyId'
        end
      end
    end

    context "when secret access key is invalid" do
      before do
        allow_any_instance_of(Aws::S3::Client).to receive(:list_buckets).and_raise(Aws::S3::Errors::SignatureDoesNotMatch)
      end

      it 'returns false' do
        expect(health_check.aws_creds!).to eq false
      end

      describe "#ok?" do
        it 'returns false' do
          health_check.aws_creds!
          expect(health_check.ok?).to eq false
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.aws_creds!
          results = health_check.results
          expect(results).to eq AWS: 'Aws::S3::Errors::SignatureDoesNotMatch'
        end
      end
    end

    context "when no keys are set" do
      before do
        allow_any_instance_of(Aws::S3::Client).to receive(:list_buckets).and_raise(NoMethodError)
      end

      it 'returns false' do
        expect(health_check.aws_creds!).to eq false
      end

      describe "#ok?" do
        it 'returns false' do
          health_check.aws_creds!
          expect(health_check.ok?).to eq false
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.aws_creds!
          results = health_check.results
          expect(results).to eq AWS: 'NoMethodError'
        end
      end
    end

    context "when login is valid" do
      before do
        allow_any_instance_of(Aws::S3::Client).to receive(:list_buckets).and_return(true)
      end

      it 'returns true' do
        expect(health_check.aws_creds!).to eq true
      end

      describe "#ok?" do
        it 'returns true' do
          health_check.aws_creds!
          expect(health_check.ok?).to eq true
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.aws_creds!
          results = health_check.results
          expect(results).to eq AWS: 'OK'
        end
      end
    end
  end

  describe "#check!" do
    describe 'name' do
      it 'can be provided' do
        health_check.check!('can_reach_the_internet') { true }
        expect(health_check.results.keys).to include(:can_reach_the_internet)
        expect(health_check.results.keys).not_to include(:custom_check)
      end

      it 'has a default' do
        health_check.check! { true }
        expect(health_check.results.keys).to include(:custom_check)
      end
    end

    context "when the given block returns a truthy value" do
      it 'returns true' do
        expect(health_check.check! { 1 + 2 }).to eq true
      end

      describe "#ok?" do
        it 'returns true' do
          health_check.check! { 1 + 2 }
          expect(health_check.ok?).to eq true
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.check! { 1 + 2 }
          results = health_check.results
          expect(results).to eq custom_check: 'OK'
        end
      end
    end

    context "when the given block returns a falsy value" do
      it 'returns true' do
        expect(health_check.check! { nil }).to eq false
      end

      describe "#ok?" do
        it 'returns false' do
          health_check.check! { nil }
          expect(health_check.ok?).to eq false
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.check! { nil }
          results = health_check.results
          expect(results).to eq custom_check: 'Failed'
        end
      end
    end
  end
end
