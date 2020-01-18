require 'watir'
require 'json'
require 'reddit_auto'

#Gets info about a subreddit and saves it inside the subreddit.json file

r = Reddit.new
r.browser = Watir::Browser.new :firefox, headless: true

sub = r.get_subreddit('AskReddit')

File.write('./subreddit.json', JSON.pretty_generate(sub))