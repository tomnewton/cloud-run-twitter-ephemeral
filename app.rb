require 'sinatra'
require 'twitter'
require 'pry'
require 'google/cloud/logging'

use Google::Cloud::Logging::Middleware

set :bind, '0.0.0.0'

$thread = nil

post '/' do
  if $thread == nil || $thread.alive? == false
    $thread = run
  end
end

def run
  Thread.new do 
    logging = Google::Cloud::Logging.new

    resource = logging.resource "cloud_run_revision", 
    revision_name: ENV["K_REVISION"], 
    service_name: ENV["K_SERVICE"],
    configuration_name: ENV["K_CONFIGURATION"]

    run_project_id = ENV["RUN_PROJECT_ID"]
    
    logger = logging.logger run_project_id, resource, env: :production

    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
      config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
      config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
      config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
    end
    
    user = client.verify_credentials
    
    time_in_the_past = Time.now - 60*60*24*30*9

    logger.info "Deleting tweets for #{user.screen_name} from before #{time_in_the_past}"
    
    options = {
      exclude_replies: false, 
      include_rts: true, 
      count: 200,
    }

    max_id = nil  
    rate_limited = 0

    begin 
      while true do 
        options[:max_id] = max_id unless !max_id

        tl = client.user_timeline(user, options)

        to_delete = tl.select { |tweet| tweet.created_at < time_in_the_past ? tweet : nil }

        if to_delete.count > 0
          logger.info "Deleting #{to_delete.count} tweets... from: #{to_delete.first.created_at} to: #{to_delete.last.created_at}"
          destroyed = client.destroy_status(to_delete)
          logger.info "Deleted #{destroyed.count}"
        end

        logger.info "tl.last: #{tl.last.id} #{tl.last.created_at}"

        if max_id == tl.last.id
          break
        end

        max_id = tl.last.id
      end

    rescue Twitter::Error::TooManyRequests
      rate_limited += 1
      sleep [2**rate_limited, 60].min
      retry
    end

    logger.info 'All done.'

  end
end
