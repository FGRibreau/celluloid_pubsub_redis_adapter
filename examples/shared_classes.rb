require 'bundler/setup'
require 'celluloid_pubsub'
require 'celluloid_pubsub_redis_adapter'
require 'logger'

debug_enabled = ENV['DEBUG'].present? && ENV['DEBUG'].to_s == 'true'
use_redis = ENV['USE_REDIS'].to_s == 'true' ? 'redis': ''
log_file_path = File.join(File.expand_path(File.dirname(__FILE__)), 'log', 'celluloid_pubsub.log')

# actor that subscribes to a channel
class Subscriber
  include Celluloid
  include Celluloid::Logger

  def initialize(options = {})
    @client = CelluloidPubsub::Client.new({ actor: Actor.current, channel: 'test_channel' }.merge(options))
  end

  def on_message(message)
    if @client.succesfull_subscription?(message)
      puts "subscriber got successful subscription #{message.inspect}"
      @client.publish('test_channel2', 'data' => ' subscriber got successfull subscription') # the message needs to be a Hash
    else
      puts "subscriber got message #{message.inspect}"
    end
  end

  def on_close(code, reason)
    puts "websocket connection closed: #{code.inspect}, #{reason.inspect}"
    terminate
  end


end

# actor that publishes a message in a channel
class Publisher
  include Celluloid
  include Celluloid::Logger

  def initialize(options = {})
    @client = CelluloidPubsub::Client.new({ actor: Actor.current, channel: 'test_channel2' }.merge(options))
  end

  def on_message(message)
    if @client.succesfull_subscription?(message)
      puts "publisher got successful subscription #{message.inspect}"
      @client.publish('test_channel', 'data' => ' my_message') # the message needs to be a Hash
    else
      puts "publisher got message #{message.inspect}"
    end
  end

  def on_close(code, reason)
    puts "websocket connection closed: #{code.inspect}, #{reason.inspect}"
    terminate
  end

end


CelluloidPubsub::WebServer.supervise_as(:web_server, enable_debug: debug_enabled, adapter: use_redis,log_file_path: log_file_path )
Subscriber.supervise_as(:subscriber, enable_debug: debug_enabled)
Publisher.supervise_as(:publisher, enable_debug: debug_enabled)
signal_received = false

Signal.trap('INT') do
  puts "\nAn interrupt signal has been triggered!"
  signal_received = true
end

sleep 0.1 until signal_received
puts 'Exited succesfully! =)'
