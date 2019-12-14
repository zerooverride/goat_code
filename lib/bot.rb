require 'set'
require 'irc-socket'
require 'json'
require "google/cloud/firestore"

TWITCH_HOST = 'irc.chat.twitch.tv'
TWITCH_PORT = 6667

class TwitchBot
  def initialize
    credentials_file = File.read('../secrets/secrets.json')
    creds = JSON.parse(credentials_file)
    ENV["FIRESTORE_CREDENTIALS"] = "../secrets/GoatCodeBot-bfea24947e39.json"
    @nickname = 'goat_code'
    @password = creds['irc_pass']
    @channel = 'goat_code'
    @socket = TCPSocket.open(TWITCH_HOST, TWITCH_PORT)
    @irc = IRCSocket.new(TWITCH_HOST)
    @firestore = Google::Cloud::Firestore.new
  end

  def run
    @irc.connect
    if @irc.connected?
      puts "connected!"
      @irc.pass @password
      @irc.nick @nickname
      @irc.user @nickname, 0, "*", @nickname

      while line = @irc.read
        if line.split[1] == '376'
          @irc.join "##{@channel}"
        end

        if line.match(/PRIVMSG ##{@channel} :(.*)$/)
          content = $~[1]
          username = line.match(/@(.*).tmi.twitch.tv/)[1]
          puts "got #{content} from #{username}"
          # get a firestore doc reference
          doc_ref = @firestore.doc("users/#{username}")
          expiration = Time.now + 60*5 # 5 minutes
          # check if the doc actually exists
          if !doc_ref.get.exists?
            # if it doesn't, create the doc and respond to the user
            doc_ref.create({expiration: expiration.to_i})
            @irc.privmsg("##{@channel}", "Welcome, #{username}! Thanks for chatting!")
          elsif doc_ref.get.get('expiration') < Time.now.to_i
            # if it does exists and is expired, respond to the user
            # and update the doc
            puts "users wait period has expired, responding."
            doc_ref.update({expiration: expiration.to_i})
            @irc.privmsg("##{@channel}", "Welcome, #{username}! Thanks for chatting!")
          else
            # user was resopnded to recently, do nothing
            puts "user already responded to and non-expired: #{doc_ref.get.get('expiration')}"
          end
        end
        puts "Received: #{line}"
      end

    end
  end
end
