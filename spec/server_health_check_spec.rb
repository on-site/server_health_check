require 'spec_helper'

module ActiveRecord
  class Base
  end
end

class Redis
  class CannotConnectError < StandardError; end
  def initialize(options = nil); end
end

module Aws
  class S3
    class Bucket
      def initialize(options = nil); end
    end
  end
  class Client
  end
end

describe ServerHealthCheck do
  it 'has a version number' do
    expect(ServerHealthCheck::VERSION).not_to be nil
  end

  describe 'typical use case' do
    context 'when all is well' do
      before do
        Redis.send(:define_method, :ping) { true }
      end

      it 'reports OK' do
        health_check = ServerHealthCheck.new
        # health_check.active_record!
        health_check.redis!(host: 'optional', port: 1234)
        # health_check.aws_s3!(bucket: 'yakmail-inbound')
        # health_check.check!(:name) do
        #   # app-specific code that wouldn't belong in the gem
        #   # return true or false
        # end
        http_status = health_check.ok? ? 200 : 500
        expect(http_status).to eq 200
        expect(health_check.results.keys).to contain_exactly(
          # :active_record,
          :redis,
          # :aws_s3,
        )
        expect(health_check.results.values).to all eq('OK')
      end
    end

    context 'when only one check fails' do
      before do
        Redis.send(:define_method, :ping) { fail Redis::CannotConnectError }
      end

      it 'reports failure' do
        health_check = ServerHealthCheck.new
        # health_check.active_record!
        health_check.redis!(host: 'optional', port: 1234)
        # health_check.aws_s3!(bucket: 'yakmail-inbound')
        # health_check.check!(:name) do
        #   # app-specific code that wouldn't belong in the gem
        #   # return true or false
        # end
        http_status = health_check.ok? ? 200 : 500
        expect(http_status).to eq 500
        expect(health_check.results.keys).to contain_exactly(
          # :active_record,
          :redis,
          # :aws_s3,
        )
        expect(health_check.results.values).to include 'Redis::CannotConnectError'
      end
    end
  end

  let(:health_check) { ServerHealthCheck.new }
  describe "#redis!" do
    context "when redis gem is not loaded" do
      around do |example|
        redis = Object.send(:remove_const, :Redis)
        example.run
        Object.send(:const_set, :Redis, redis)
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
        Redis.send(:define_method, :ping) { fail Redis::CannotConnectError }
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
        Redis.send(:define_method, :ping) { true }
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
      around do |example|
        active_record = Object.send(:remove_const, :ActiveRecord)
        example.run
        Object.send(:const_set, :ActiveRecord, active_record)
      end
      it 'raises an execpetion' do
        expect { health_check.active_record! }.to raise_error(NameError, /ActiveRecord/)
      end
    end

    context "when database is not reachable" do
      before do
        ActiveRecord::Base.send(:define_singleton_method, :connected?) { false }
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
          expect(results).to eq database: 'Failed: unable to connect to database'
        end
      end
    end

    context "when database is reachable" do
      before do
        ActiveRecord::Base.send(:define_singleton_method, :connected?) { true }
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
          expect(results).to eq database: 'OK'
        end
      end
    end
  end

  describe "#aws_s3" do
    context "when aws-sdk gem is not loaded" do
      around do |example|
        aws = Object.send(:remove_const, :Aws)
        example.run
        Object.send(:const_set, :Aws, aws)
      end
      it 'raises an execpetion' do
        expect { health_check.aws_s3 }.to raise_error(NameError, /Aws/)
      end
    end

    context "when bucket does not exist" do
      before do
        Aws::S3::Bucket.send(:define_method, :exists?) { false }
      end
      it 'returns false' do
        expect(health_check.aws_s3('test-bucket')).to eq false
      end

      describe "#ok?" do
        it 'returns false' do
          health_check.aws_s3
          expect(health_check.ok?).to eq false
        end
      end

      describe "#results" do
        it 'returns a hash with string results' do
          health_check.aws_s3
          results = health_check.results
          expect(results).to eq S3: 'Failed: bucket does not exist'
        end
      end
    end
  end
end
