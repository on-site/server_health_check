require 'spec_helper'

describe ServerHealthCheck do
  it 'has a version number' do
    expect(ServerHealthCheck::VERSION).not_to be nil
  end

  class Redis
    class CannotConnectError < StandardError; end
    def initialize(options = nil); end
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

    end
  end
end
