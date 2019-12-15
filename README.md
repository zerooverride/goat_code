# goat_code

# Running the TwitchBot
1. Get Firebase and Twitch chat creds
2. From lib/ run `irb -r ./bot.rb`
3. In irb, start the bot: `bot = TwitchBot.new; bot.run`
4. In chat, set the current streamer by sending the command `!set_streamer <your username>` for example `!set_streamer ZeroOverride`
---------------------------------------------------
# TODO
* ChatBot - in progress
- Responds to new chatters - Done.
 - re-responds to people who have been away for a while - done.
- Responds to IRC pings (so it doesn't die if there's no chatters!) - I think this works
- Has actions
  - can take a question
    - writes to questions collection - done
  - can set who the current streamer is (admin only) - done
  - can tell who the current streamer is - done

* Custom overlay
- Figure out frontend
  - one of:
  - OBS Browser source - definitely can work with transparent background
  - Twitch extension - seems similar to obs browser source, maybe more complicated to build but doesn't need to be set up in each persons obs I guess

- Figure out backend
