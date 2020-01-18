require 'watir'
require 'json'
require 'reddit_auto'

#Gets all visible comments from the first post of given subreddit and saves
#it in the comments.json file

if ARGV.length < 1
  puts 'Usage: ruby get_comments.rb subreddit'
  exit
end

r = Reddit.new

r.browser = Watir::Browser.new :firefox, headless: true

posts = r.get_posts(ARGV[0])

comments = r.get_comments(posts[0])

File.write('./comments.json', JSON.pretty_generate(comments))