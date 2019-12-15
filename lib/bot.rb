require 'irc-socket'
require 'json'
require 'google/cloud/firestore'
require 'securerandom'

TWITCH_HOST = 'irc.chat.twitch.tv'
TWITCH_PORT = 6667

class TwitchBot
  def initialize
    # Twitch chat credentials
    credentials_file = File.read('../secrets/secrets.json')
    creds = JSON.parse(credentials_file)
    # Firebase service account credentials
    ENV['FIRESTORE_CREDENTIALS'] = '../secrets/GoatCodeBot-creds.json'
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
      puts 'connected!'
      @irc.pass @password
      @irc.nick @nickname
      @irc.user @nickname, 0, '*', @nickname

      while line = @irc.read
        puts "Received: #{line}"

        # wait for MOTD to finish
        if line.split[1] == '376'
          # join our chat channel
          @irc.join "##{@channel}"
        end

        # look for PING messages
        if line.match(/^PING :tmi.twitch.tv$/)
          # keeps the bot from getting disconnected
          puts "got a PING, sending a PONG"
          @irc.pong('tmi.twitch.tv')
        end

        # look for user messages
        if line.match(/PRIVMSG ##{@channel} :(.*)$/)
          content = $~[1]
          username = line.match(/@(.*).tmi.twitch.tv/)[1]
          # get a firestore doc reference for this user
          doc_ref = @firestore.doc("users/#{username}")
          expiration = Time.now + 60*60*24*2 # expire the record after 2 days
          # check if the doc actually exists
          if !doc_ref.get.exists?
            # if it doesn't, create the doc and respond to the user
            doc_ref.create({expiration: expiration.to_i})
            @irc.privmsg("##{@channel}", "Welcome to the channel, #{username}! Thanks for chatting!")
          elsif doc_ref.get.get('expiration') < Time.now.to_i
            # if it does exists and is expired, update the doc
            # and respond to the user
            puts 'users wait period has expired, responding.'
            doc_ref.update({expiration: expiration.to_i})
            @irc.privmsg("##{@channel}", "It's been a while, #{username}! Thanks for chatting!")
          else
            # user was resopnded to recently, do nothing
            puts "user already responded to and non-expired: #{doc_ref.get.get('expiration')}"
          end

          # look for commands
          if content.match(/^!(\w+)( )?(.*)/)
            puts "Got a command message"
            command = $~[1]
            command_content = $~[3]
            puts "command: #{command}"
            puts "command_content: #{command_content}"
            if command == 'question' || command == 'q'
              question_command(command_content)
            elsif command == 'streamer' || command == 'whodisis'
              streamer_command
            elsif command == 'set_streamer'
              set_streamer(username, command_content)
            end
          end
        end

      end
    end
  end

  # Stores a questions in Firebase
  # we'll need a way to clear these too
  def question_command(content)
    # !question What is a Set in Ruby?
    question_id = SecureRandom.uuid
    question_doc = @firestore.doc("questions/#{question_id}")
    question_doc.create({question_content: content})
  end

  # Run this command at the start of the stream with your username
  # or the streamer command will say the last person who did
  def set_streamer(user, streamer)
    # only we should be able to use this command
    if user == 'goat_code'
      stream_doc = @firestore.doc("streamer/streamer")
      if stream_doc.get.exists?
        stream_doc.update({user_name: streamer})
      else
        stream_doc.create({user_name: streamer})
      end
    end
  end

  # Respond with the current straemer and a link to their channel
  # should this @ the person who sent the command?
  def streamer_command
    stream_doc_ref = @firestore.doc("streamer/streamer")
    stream_doc_snap = stream_doc_ref.get
    user_name = stream_doc_snap.get('user_name')

    @irc.privmsg("##{@channel}", "#{user_name} is streaming! https://twitch.tv/#{user_name}")
  end
end
