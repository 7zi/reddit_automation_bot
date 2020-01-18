require 'watir'
require 'reddit_auto'

COMMENT = 'Free karma please!'

#Logins and posts a comment to the first topic of a given subreddit

if ARGV.length < 3
  puts 'Usage: ruby post_comment.rb username password subreddit'
  exit
end

r = Reddit.new
r.browser = Watir::Browser.new :firefox, headless: false

r.login(ARGV[0], ARGV[1])

posts = r.get_posts(ARGV[2])

r.reply_post(posts[0], COMMENT)

sleep 999