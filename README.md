[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=NAT333XURSXGY&source=url)

# Reddit Automation Bot

Reddit auto is a ruby gem that allows you to automate several aspects of reddit.
It doesn't use the reddit api, instead uses watir/selenium to automate.

## Features

You can automate several things, here are some examples:

* Account creation
* Subreddit creation
* Link/Text submitting
* Commenting on posts
* Scraping

## Installation

`gem install reddit_auto`

## Usage

You just have to start a class instance and assign a browser to it.

```ruby
  require 'watir'
  require 'reddit_auto'

  r = Reddit.new
  r.browser = Watir::Browser.new :firefox, headless: true

  #your code here...
```

See some examples in the Examples folder.


## Author

Ícaro Augusto

* [https://icaroaugusto.com](https://icaroaugusto.com)
* Discord: **IcaroAugusto#3303**

## Changelogs

### 1.1

Added documentation.

### 1.0

Created.