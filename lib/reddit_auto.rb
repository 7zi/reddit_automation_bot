require 'watir'

#Written by Ícaro Augusto
#Website: https://icaroaugusto.com
#Github: https://github.com/IcaroAugusto

NewSub = Struct.new(
  :name,
  :title,
  :description,
  :sidebar,
  :subtext,
  :type,
  :content
)

class Reddit
	PAGE_MAIN = 'https://old.reddit.com/'
	PAGE_MAIN_NO_SLASH = 'https://old.reddit.com'
	PAGE_MESSAGES = 'https://old.reddit.com/message/'
	PAGE_SUBREDDIT = 'https://old.reddit.com/r/'
	PAGE_USER = 'https://old.reddit.com/user/'
	PAGE_CREATE_SUB = 'https://old.reddit.com/subreddits/create'

	MESSAGE_SUBPAGES = ['inbox', 'unread', 'messages', 'comments', 'sent']
	SUBREDDIT_SUBPAGES = ['hot', 'new', 'rising', 'top', 'gilded']
	USER_SORTBYS = ['new', 'hot', 'top', 'controversial']

  SUB_TYPES = {
    'public' => 'type_public',
    'restricted' => 'type_restricted',
    'private' => 'type_private',
    'premium only' => 'type_gold_only'
  }

  CONTENT_OPTIONS = {
    'any' => 'link_type_any',
    'links only' => 'link_type_link',
    'text posts only' => 'link_type_self'
  }

	attr_accessor :browser
	attr_accessor :username

  # Checks if the class has a browser assigned
  #
  # @return [Boolean]
	def has_browser
		return @browser != nil
	end

  # Checks if a given account is logged in
  #
  # @param username [String] the account's username
  # @return [Boolean] whether it is logged in or not
	def is_logged_in(username)
		return @browser.link(text: username).present?
	end

  # Waits for a successful loggin, raises an exception if it fails to login
  #
  # @param username [String] the account's username
	def wait_login(username)
		count = 0.0
		while !is_logged_in(username)
			sleep 0.25
			count += 0.25
			if count > 10
				raise 'Reddit login failed for username: ' + username
			end
		end
	end

  # Logins the reddit website, raises an exception on failure
  #
  # @param username [String] the account's username
  # @param password [String] the account's password
	def login(username, password)
		@username = username
		@browser.goto PAGE_MAIN
		@browser.text_field(name: 'user').set username
		@browser.text_field(name: 'passwd').set password
		@browser.checkbox(id: 'rem-login-main').set
		@browser.button(text: 'login').click
		wait_login(username)
	end

  # Waits for logout, raises an exception on failure
	def wait_logout
		count = 0.0
		while is_logged_in(@username)
			sleep 0.25
			count += 0.25
			if count > 10
				raise 'Reddit logout failed for username: ' + @username
			end
		end
	end

  # Waits for logout, raises an exception on failure
	def logout
		@browser.link(text: 'logout').click
		wait_logout
	end

  # Checks if reddit is asking if user is over 18 for nsfw content
  #
  # @return [Boolean] whether the prompt is present or not
	def has_over_18
		return @browser.button(name: 'over18').present?
	end

  # Skips the are you over 18 prompt
	def skip_over_18
		@browser.button(text: 'continue').click
	end

  # Checks if reddit is asking if user is over 18 for nsfw content, uses the new interface
  #
  # @return [Boolean] whether the prompt is present or not
	def has_over_18_new
		return @browser.h3(text: 'You must be 18+ to view this community').present?
	end

  # Skips the are you over 18 prompt, uses the new interface
	def skip_over_18_new
		@browser.link(text: 'Yes').click
	end

	#---------------------------------------------------------------------------------
	#Messages handling
	#---------------------------------------------------------------------------------

  # Gets the type of a message
  #
  # @param div [Watir::Div] the div containing the message
  # @return [String] the message type
	def get_message_type(div)
		return div.attribute_value('data-type')
	end

  # Gets the post that a message belongs to
  #
  # @param div [Watir::Div] the div containing the message
  # @return [String] a link to the post
	def get_message_post(div)
		return div.p(class: 'subject').link(class: 'title').href
	end

  # Gets the reddit user who posted the message
  #
  # @param div [Watir::Div] the div containing the message
  # @return [String] the username of the message's author
	def get_message_author(div)
		return div.attribute_value('data-author')
	end

  # Gets the subreddit which the message was posted in
  #
  # @param div [Watir::Div] the div containing the message
  # @return [String] the subreddit
	def get_message_subreddit(div)
		return div.attribute_value('data-subreddit')
	end

  # Gets the content of the message
  #
  # @param div [Watir::Div] the div containing the message
  # @return [String] the message's content
	def get_message_content(div)
		return div.div(class: 'md').text
	end

  # Gets all message divs in the page
  #
  # @return [Array<Watir::Div>] an array containing all message divs in the page
	def get_message_divs
		all_divs = @browser.div(id: 'siteTable').divs
		result = []
		all_divs.each do |div|
			result.push div if div.id.include? 'thing_'
		end
		return result
	end

  # Checks if a given message is voted by the logged in user
  #
  # @param div [Watir::Div] the div containing the message
  # @param type [String] the type of vote, can be 'up' or 'down'
  # @return [Boolean] whether the message is voted in the given type
	def is_message_voted(div, type)
		return div.div(class: 'midcol').div(class: type + 'mod').present?
	end

  # Gets the type of vote the given message received from the logged in user
  #
  # @param div [Watir::Div] the div containing the message
  # @return [String, nil] returns 'up' or 'down' if voted or nil if not voted
	def get_message_vote(div)
		return 'up' if is_message_voted(div, 'up')
		return 'down' if is_message_voted(div, 'down')
		return nil
	end

  # Votes the given message
  #
  # @param div [Watir::Div] the div containing the message
  # @param type [String] the type of vote, can be 'up' or 'down'
	def vote_message(div, type)
		return if is_message_voted(div, type)
		div.div(class: 'midcol').div(class: type).click
	end

  # Replies the given message
  #
  # @param div [Watir::Div] the div containing the message
  # @param answer [String] answer, the content of the reply
	def reply_message(div, answer)
		div.li(text: 'reply').click
		div.textarea.set answer
		div.button(text: 'save').click
	end

  # Gets a hash object containing information about a given message
  #
  # @param div [Watir::Div] the div containing the message
  # @return [Hash] a hash containing informaton about the given message
	def get_message(div) #returns a hash with message data
		result = {}
		result['type'] = get_message_type(div)
		result['author'] = get_message_author(div)
		result['post'] = get_message_post(div) if result['type'] == 'comment'
		result['subreddit'] = result['type'] == 'comment' ? get_message_subreddit(div) : result['author']
		result['vote'] = get_message_vote(div) if result['type'] == 'comment'
		result['content'] = get_message_content(div)
		return result
	end

  # Moves to the next or previous page in the message inbox
  #
  # @param direction [String] the direction to move, can be 'next' or 'prev'
  # @return [Boolean] returns true if moved to the desired page or false if didn't because you're already in the last (move next) or first (move prev) page
	def message_move_page(direction)
		button = @browser.span(class: direction + '-button')
		result = button.present?
		button.click if result
		return result
	end

  # Opens the messages subpage, raises an exception if an unknown subpage is given
  #
  # @param subpage [String] the subpage to open, can be: 'inbox', 'unread', 'messages', 'comments' or 'sent'
	def open_messages_subpage(subpage)
		raise 'Unknown message subpage: ' + subpage if !MESSAGE_SUBPAGES.include? subpage
		@browser.goto PAGE_MESSAGES + subpage
	end

  # Gets all the messages in a given subpage, raises an exception if an unknown subpage is given
  #
  # @param subpage [String] the subpage to open, can be: 'inbox', 'unread', 'messages', 'comments' or 'sent'
  # @param all_pages [Boolean] if true will check all pages, if false will check only the first page
  # @return [Array] an array containing hashes with information about all pages 
	def get_messages(subpage, all_pages = false)
		open_messages_subpage(subpage)
		result = []
		while true
			get_message_divs.each do |div|
				result.push get_message(div)
			end
			return result if !all_pages || !message_move_page('next')
		end
	end

	#---------------------------------------------------------------------------------
	#Submit handling
	#---------------------------------------------------------------------------------

  # Checks if there was an error when submiting to a subreddit, typically because of the 10 minute cooldown between posts enforced by reddit
  #
  # @return [Boolean] whether there as an error or not
	def has_submit_error
		return @browser.span(text: 'you are doing that too much. try again in').present?
	end

  # Checks if the submit page is open
  #
  # @return [Boolean] whether the page is open or not
	def is_submit_open
		return @browser.textarea(name: 'title').present? || @browser.textarea(placeholder: 'Title').present?
	end

  # Waits for the submit page to open, raises an exception if it fails to open after 10 seconds
	def wait_submit
		count = 0.0
		while is_submit_open
			sleep 0.25
			count += 0.25
			raise 'Post submission failed!' if count >= 10
		end
	end

  # Submits a link to the given subreddit, raises an exception on failure
  #
  # @param subreddit [String] the name of the subreddit to submit the link to
  # @param url [String] the url to submit
  # @param title [String] the title of the post
	def submit_link(subreddit, url, title)
		@browser.goto PAGE_SUBREDDIT + subreddit + '/submit'
		skip_over_18 if has_over_18
		@browser.text_field(id: 'url').set url
		@browser.textarea(name: 'title').set title
		@browser.button(name: 'submit').click
		wait_submit
	end

  # Checks if the subreddit has an option to add a flair to posts
  #
  # @return [Boolean] whether or not it has a flair option
	def sub_has_flair
		return !@browser.div('aria-label': 'Not available for this community').present?
	end

  # Sets the given flair to the post, does nothing if the subreddit has no flair option
  #
  # @param flair [String] the desired flair
	def set_flair(flair)
		return if !sub_has_flair
		@browser.div('aria-label': 'Add flair').click
		if flair == nil
			@browser.div('aria-label': 'flair_picker').div.click
		else
			@browser.div('aria-label': 'flair_picker').span(text: flair).click
		end
		@browser.button(text: 'Apply').click
	end

  # Submits a link to the given subreddit using the new interface, raises an exception on failure
  #
  # @param subreddit [String] the name of the subreddit to submit the link to
  # @param url [String] the url to submit
  # @param title [String] the title of the post
  # @param flair [String, nil] the flair to add, if nil will add no flair to the post
	def submit_link_new(subreddit, url, title, flair = nil) #uses new reddit
		@browser.goto 'https://www.reddit.com/r/' + subreddit + '/submit'
		skip_over_18_new if has_over_18_new
		blink = @browser.button(text: 'Link')
		blink.click if blink.present?
		@browser.textarea(placeholder: 'Title').set title
		@browser.textarea(placeholder: 'Url').set url
		set_flair(flair)
		@browser.buttons(text: 'Post')[1].click
		wait_submit
	end

  # Submits a text post to the given subreddit, raises an exception on failure
  #
  # @param subreddit [String] the name of the subreddit to submit the link to
  # @param title [String] the title of the post
  # @param text [String] the text content of the post
	def submit_text(subreddit, title, text)
		@browser.goto PAGE_SUBREDDIT + subreddit + '/submit?selftext=true'
		skip_over_18 if has_over_18
		@browser.textarea(name: 'title').set title
		@browser.textarea(name: 'text').set text
		@browser.button(name: 'submit').click
		wait_submit
	end

	#---------------------------------------------------------------------------------
	#Post handling
	#---------------------------------------------------------------------------------

  # Checks if the currently open post is voted by the logged in account, raises an exception if an unknown vote type is submitted
  #
  # @param type [String] the vote type, can be 'up' or 'down'
  # @return [Boolean] whether or not the original post is voted in the given type
	def is_original_post_voted(type)
		div = @browser.div(id: 'siteTable').div(class: 'midcol')
		case type
		when 'up'
			return div.attribute_value('class') == 'midcol likes'
		when 'down'
			return div.attribute_value('class') == 'midcol dislikes'
		else
			raise 'Unknown vote type: ' + type
		end
	end

  # Gets the type of the vote the logged in account voted the original post that is currently open
  #
  # @return [String, nil] returns the vote type, 'up' or 'down' or nil if not voted
	def get_original_post_vote
		return 'up' if is_original_post_voted('up')
		return 'down' if is_original_post_voted('down')
		return nil
	end

  # Votes the currently open original post, does nothing if already voted, raises an exception if an unknown vote type is submitted
  #
  # @param type [String] vote type: 'up' or 'down'
	def vote_original_post(type)
		return if is_original_post_voted(type)
		div = @browser.div(id: 'siteTable').div(class: 'midcol')
		div.div(class: type).click
	end

  # Forms the full post url given the post's link
  #
  # @param link [String] the post's link
  # @return [String] the full post url
	def form_post_url(link)
		return PAGE_MAIN_NO_SLASH + link
	end

  # Opens the given post
  #
  # @param post [Hash, String] accepts either a post hash or the post's full url
	def open_post(post)
    case post
    when Hash
      @browser.goto form_post_url(post['link'])
    when String
      @browser.goto post
    else
      return
    end
    skip_over_18 if has_over_18
	end

  # Checks if the logged in account has already replied to the given post with the given answer
  #
  # @param answer [String] the answer to look for
  # @return [Boolean] whether or not the logged in account replied to the post with the given answer
	def has_reply(answer)
		form = @browser.form(text: answer)
		return form.present? && form.parent.parent.attribute_value('data-author') == @username
	end

  # Checks if there was an error when replying
  #
  # @return [Boolean] whether there was an error or not
	def has_reply_error
		return @browser.span(class: 'error', style: '').present?
	end

  # Gets the reason for the reply error
  #
  # @return [String] the reason
	def get_reply_error
		return @browser.span(class: 'error', style: '').split(" ")[1]
	end

  # Sleeps the given time then checks if there was an error when replying
  #
  # @param time [Integer] the number of seconds to sleep
  # @return [Boolean] whether there was an error or not
	def wait_reply(time = 2)
		sleep time
		return !has_reply_error
	end

  # Replies the given post
  #
  # @param post [Hash, String] the post to reply, can be a post hash or full url
  # @param answer [String] the answer to the post
  # @return [Boolean] if replying as successful
	def reply_post(post, answer)
    open_post(post)
		@browser.div(class: 'commentarea').textarea(name: 'text').set answer
		@browser.div(class: 'commentarea').button(text: 'save').click
		return wait_reply
	end

  # Gets the number of replies the given comment received
  #
  # @param div [Watir::Div] a div containing the comment
  # @return [Integer] the number of replies
	def get_comment_replies_count(div)
		return div.attribute_value('data-replies').to_i
	end

  # Checks if a given comment has replies
  #
  # @param div [Watir::Div] a div containing the comment
  # @return [Boolean] if the comment has replies or not
	def comment_has_replies(div)
		return div.attribute_value('data-replies') != '0'
	end

  # Gets the author of the comment
  #
  # @param div [Watir::Div] a div containing the comment
  # @return [String] the author's username
	def get_comment_author(div)
		return div.attribute_value('data-author')
	end

  # Gets the link of the comment
  #
  # @param div [Watir::Div] a div containing the comment
  # @return [String] the link of the comment
	def get_comment_link(div)
		return div.attribute_value('data-permalink')
	end

  # Gets content of the comment
  #
  # @param div [Watir::Div] a div containing the comment
  # @return [String] the content of the comment
	def get_comment_content(div)
		return div.div(class: 'usertext-body').text
	end

  # Gets the amount of karma the comment received, 'up', 'down' or overall
  #
  # @param div [Watir::Div] a div containing the comment
  # @param vote [String, nil] 'up' for number of upvotes, 'down' for downvotes, nil for total
  # @return [Integer] the number of votes/karma
	def get_comment_karma(div, vote)
		case vote
		when 'up'
			ind = 2
		when 'down'
			ind = 0
		else
			ind = 1
		end
		return div.p(class: 'tagline').spans(class: 'score')[ind].text.split(' ')[0].to_i
	end

  # Checks if the comment is voted by the logged in account, 'up' or 'down', raises an exception if an unknown vote type is submitted
  #
  # @param div [Watir::Div] a div containing the comment
  # @param type [String] the vote type, 'up' or 'down'
  # @return [Boolean] if the comment is voted
	def is_comment_voted(div, type)
		case type
		when 'up'
			buffer = 'likes'
		when 'down'
			buffer = 'dislikes'
		else
			raise 'Unknown vote type!'
		end
		return div.div(class: 'entry').attribute_value('class') == 'entry ' + buffer
	end

  # Gets the comment's vote by the logged in account
  #
  # @param div [Watir::Div] a div containing the comment
  # @return [String, nil] 'up' if upvoted, 'down' if downvoted, nil if not voted
	def get_comment_vote(div)
		return 'up' if is_comment_voted(div, 'up')
		return 'down' if is_comment_voted(div, 'down')
		return nil
	end

  # Checks if the given comment has karma
  #
  # @param div [Watir::Div] a div containing the comment
  # @return [Boolean] whether the comment has karma or not
	def comment_has_karma(div)
		return div.span(class: 'score').present?
	end

  # Gets a hash containing information about a given comment
  #
  # @param div [Watir::Div] a div containing the comment
  # @return [Hash] a hash containing information about a given comment
	def get_comment(div)
		result = {}
		result['author'] = get_comment_author(div)
		result['link'] = get_comment_link(div)
		result['content'] = get_comment_content(div)
		result['vote'] = get_comment_vote(div)
		result['karma'] = get_comment_karma(div, result['vote']) if comment_has_karma(div)
		return result
	end

  # Gets all the comments' divs in the open page
  #
  # @return [Array] an array containing all comments' divs in the open page
	def get_comments_divs
		divs = @browser.div(class: 'commentarea').div(class: 'sitetable nestedlisting').children
		result = []
		divs.each do |div|
			result.push div if div.attribute_value('data-type') == 'comment'
		end
		return result
	end

  # Gets all replies' divs to the given comment
  #
  # @param div [Watir::Div] a div containing the comment
  # @return [Array] an array containing all replies' divs to the given comment
	def get_replies_divs(main_div)
		divs = main_div.div(class: 'child').div.children
		begin
			x = divs.length
		rescue
			return []
		end
		result = []
		divs.each do |div|
			result.push div if div.attribute_value('data-type') == 'comment'
		end
		return result
	end

  # Parses all the comments divs and replies
  #
  # @param div [Watir::Div] a div containing the comment
  # @return [Array] an array of hashes containing the comments and their replies
	def parse_comments_divs(divs)
		result = []
		divs.each do |div|
			result.push get_comment(div)
			if comment_has_replies(div)
				result[result.length-1]['replies'] = parse_comments_divs(get_replies_divs(div))
			end
		end
		return result
	end

  # Expands all comments in the open page
	def expand_all_comments
		while true
			begin
				span = @browser.span(class: 'morecomments')
				span.present? ? span.click : return
			rescue
			end
			sleep 0.5
		end
	end

  # Gets all the comments in the given post
  #
  # @param post [String, Hash] a post hash or full url
  # @param expand [Boolean] whether to expand all the comments first
  # @return [Array] an array of hashes including information about all the comments and their replies
	def get_comments(post, expand = false)
		open_post(post)
		expand_all_comments if expand
		return parse_comments_divs(get_comments_divs)
	end

  # Replies the given comment with the given anwer
  #
  # @param div [Watir::Div] a div containing the comment
  # @param answer [String] the answer
	def reply_comment(div, answer)
		div.li(text: 'reply').click
		div.textarea(name: 'text').set answer
		div.button(class: 'save').click
	end

  # Votes the given comment
  #
  # @param div [Watir::Div] a div containing the comment
  # @param type [String] the vote type can be 'up' or 'down'
	def vote_comment(div, type)
		return if is_comment_voted(div, type)
		div.div(class: 'midcol').div(class: type).click
	end

	#---------------------------------------------------------------------------------
	#Subreddit handling
	#---------------------------------------------------------------------------------

  # Gets all the posts' divs
  #
  # @return [Array] an array containing all posts' divs
	def get_posts_divs
		divs = @browser.div(id: 'siteTable').children
		result = []
		divs.each do |div|
			result.push div if div.attribute_value('data-type') == 'link'
		end
		return result
	end

  # Gets the author of the post
  #
  # @param div [Watir::Div] a div containing the post
  # @return [String] the author of the post
	def get_post_author(div)
		return div.attribute_value('data-author')
	end

  # Gets the link of the post
  #
  # @param div [Watir::Div] a div containing the post
  # @return [String] the link of the post
	def get_post_link(div)
		return div.attribute_value('data-permalink')
	end

  # Gets the amount of karma of the post
  #
  # @param div [Watir::Div] a div containing the post
  # @return [Integer] the amount of karma the post received
	def get_post_karma(div)
		return div.attribute_value('data-score').to_i
	end

  # Gets the title of the post
  #
  # @param div [Watir::Div] a div containing the post
  # @return [String] the title of the post
	def get_post_title(div)
		return div.link(class: 'title').text
	end

  # Gets the number of comments in the post
  #
  # @param div [Watir::Div] a div containing the post
  # @return [Integer] the number of comments in the post
	def get_post_number_of_comments(div)
		return div.attribute_value('data-comments-count').to_i
	end

  # Checks if the post is voted in the given type
  #
  # @param div [Watir::Div] a div containing the post
  # @param type [String] the type of vote: 'up' or 'down'
  # @return [Boolean] whether the post is voted or not in the given type
	def is_post_voted(div, type)
		return is_comment_voted(div, type)
	end

  # Gets the type of vote the post has
  #
  # @param div [Watir::Div] a div containing the post
  # @return [String, nil] the of vote, 'up', 'down' or nil if not voted
	def get_post_vote(div)
		return get_comment_vote(div)
	end

  # Votes the given post, 'up' or 'down', raises exception if unknown vote type is sumited
  #
  # @param div [Watir::Div] a div containing the post
  # @param type [String] the type of vote: 'up' or 'down'
	def vote_post(div, type)
		vote_comment(div, type)
	end

  # Gets a hash containing information about a given post
  #
  # @param div [Watir::Div] a div containing the post
  # @return [Hash] a hash containing information about a given post
	def get_post(div)
		result = {}
		result['author'] = get_post_author(div)
		result['link'] = get_post_link(div)
		result['karma'] = get_post_karma(div)
		result['title'] = get_post_title(div)
		result['vote'] = get_post_vote(div)
		result['number_of_comments'] = get_post_number_of_comments(div)
		return result
	end

  # Moves to the next or previous page in the subreddit
  #
  # @param direction [String] the direction to move, can be 'next' or 'prev'
  # @return [Boolean] returns true if moved to the desired page or false if didn't because you're already in the last (move next) or first (move prev) page
	def subreddit_move_page(direction)
		return message_move_page(direction)
	end

  # Forms the full subreddit url given the subreddit's name
  #
  # @param name [String] the subreddit's name
  # @param subpage [String] the subreddit's subpage, defaults to 'hot'
  # @return [String] the full subreddit url
  def form_subreddit_url(name, subpage = 'hot')
    return PAGE_SUBREDDIT + name + '/' + subpage
  end

  # Opens the given subreddit in the given subpage, raises an exception if an unknown subpage is given, known subpages: 'hot', 'new', 'rising', 'top', 'gilded'
  #
  # @param subreddit [String, Hash] a subreddit's name or hash
  # @param subpage [String] the subreddit's subpage, defaults to 'hot'
	def open_subreddit(subreddit, subpage = 'hot')
		raise 'Unknown subreddit subpage: ' + subpage if !SUBREDDIT_SUBPAGES.include? subpage
    case subreddit
    when Hash
      @browser.goto form_subreddit_url(subreddit['name'], subpage)
    when String
      if subreddit.include? '/'
        @browser.goto subreddit
      else
        @browser.goto form_subreddit_url(subreddit, subpage)
      end
    else
      return
    end
		skip_over_18 if has_over_18
	end

  # Gets all the posts in the given subreddit
  #
  # @param subreddit [String, Hash] a subreddit's name or hash
  # @param subpage [String] the subreddit's subpage, defaults to 'hot'
  # @param max_pages [Integer] maximum amount of pages to gather posts from
  # @return [Array] an array containing hashes with information about the subreddit's posts
	def get_posts(subreddit, subpage = 'hot', max_pages = 1)
		open_subreddit(subreddit, subpage)
		result = []
		count = 0
		while true
			get_posts_divs.each do |div|
				result.push get_post(div)
			end
			count += 1
			break if count >= max_pages
			break if !subreddit_move_page('next')
		end
		return result
	end

  # Forms the full url for the subreddit's moderator's page
  #
  # @param subreddit [String, Hash] a subreddit's name or hash
  # @return [String] the full url for the subreddit's moderator's page
  def form_subreddit_mod_url(subreddit)
    case subreddit
    when Hash
      return PAGE_SUBREDDIT + subreddit['name'] + '/about/moderators'
    when String
      return PAGE_SUBREDDIT + subreddit + '/about/moderators'
    end
  end

  # Gets an array including the usernames of the moderators of the given subreddit
  #
  # @param subreddit [String, Hash] a subreddit's name or hash
  # @return [Array] an array including the usernames of the moderators of the given subreddit
	def get_moderators(subreddit)
		@browser.goto form_subreddit_mod_url(subreddit)
		spans = @browser.div(class: 'moderator-table').spans(class: 'user')
		result = []
		spans.each do |span|
			result.push span.link.text
		end
		return result
	end

  # Gets the number of subscribers the subreddit currently open has
  #
  # @return [Integer] the number of subscribers the subreddit currently open has 
	def get_subscribers
		return @browser.span(class: 'subscribers').span(class: 'number').text.gsub(',', '').to_i
	end

  # Gets the number of online users the subreddit currently open has
  #
  # @return [Integer] the number of online users the subreddit currently open has 
	def get_users_online
		return @browser.p(class: 'users-online').span(class: 'number').text.gsub(',', '').to_i
	end

  # Gets content of the subreddit currently open sidebar
  #
  # @return [String] the content of the subreddit's sidebar 
	def get_side_bar
		return @browser.div(class: 'usertext-body').text
	end

  # Gets a hash with information about the given subreddit
  #
  # @param subreddit [String] the subreddit's name
  # @return [Hash] a hash with information about the given subreddit
	def get_subreddit(subreddit)
		result = {}
		result['name'] = subreddit
		open_subreddit(subreddit)
		result['subscribers'] = get_subscribers
		result['users_online'] = get_users_online
		result['sidebar'] = get_side_bar
		result['moderators'] = get_moderators(subreddit)
		return result
	end

  # Checks if the subreddit was successfully created
  #
  # @return [Boolean] whether the subreddit was successfully created 
	def did_create_sub
		return @browser.p(text: 'your subreddit has been created').present?
	end

  # Waits for the creation of the subreddit
  #
  # @return [Boolean] whether the subreddit was successfully created 
	def wait_sub_creation
		count = 0.0
		while true
			return true if did_create_sub
			sleep 0.25
			count += 0.25
			return false if count >= 10
		end
	end

  # Creates a subreddit with the given parameters
  #
  # @param subreddit [NewSub] A Struct containing the subreddit's parameters 
  # @return [Boolean] whether the subreddit was successfully created 
	def create_subreddit(subreddit)
		@browser.goto CREATE_SUB_PAGE
		@browser.text_field(id: 'name').set subreddit.name
		@browser.text_field(id: 'title').set subreddit.title
		@browser.textarea(name: 'public_description').set subreddit.description
		@browser.textarea(name: 'description').set subreddit.sidebar
		@browser.textarea(name: 'submit_text').set subreddit.subtext
		@browser.radio(id: SUB_TYPES[subreddit.type]).set
		@browser.radio(id: CONTENT_OPTIONS[subreddit.content]).set
		@browser.button(text: 'create').click
		return wait_sub_creation
	end

	#---------------------------------------------------------------------------------
	#User handling
	#---------------------------------------------------------------------------------

  # Gets the currently open user's post karma
  #
  # @return [Integer] the currently open user's post karma
	def get_user_post_karma
		return @browser.span(class: 'karma').text.gsub(',', '').to_i
	end

  # Gets the currently open user's comment karma
  #
  # @return [Integer] the currently open user's comment karma
	def get_user_comment_karma
		return @browser.spans(class: 'karma')[1].text.gsub(',', '').to_i
	end

  # Checks if the currently open user is a moderator of any subreddit
  #
  # @return [Boolean] if the currently open user is a moderator of any subreddit
	def is_moderator
		return @browser.ul(id: 'side-mod-list').present?
	end

  # Gets the currently open user's moderating pages 
  #
  # @return [Array] an array of strings containing the names of the subreddits
	def get_moderating
		result = []
		@browser.ul(id: 'side-mod-list').lis.each do |li|
			result.push li.link.title.split('/')[1]
		end
		return result
	end

  # Checks if the currently open user is a friend of the logged in account
  #
  # @return [Boolean] if the currently open user is a friend of the logged in account
	def is_friend
		return @browser.span(class: 'fancy-toggle-button').link(text: '- friends').attribute_value('class').include?('active')
	end

  # Adds the currently open user as a friend, does nothing if the user is already a friend
	def add_friend
		return if is_friend
		@browser.link(text: '+ friends').click
	end

  # Removes the currently open user as a friend, does nothing if the user is not a friend
	def remove_friend
		return if !is_friend
		@browser.link(text: '- friends').click
	end

  # Opens the page of the given username
  #
  # @param user [String] the username
	def open_user_page(user)
		@browser.goto PAGE_USER + user
		skip_over_18 if has_over_18
	end

  # Gets a hash containing information about the given user
  #
  # @param user [String] the username
  # @return [Hash] a hash containing information about the given user
	def get_user(user)
		open_user_page(user)
		return nil if @browser.div(id: 'classy-error').present?
		result = {}
		result['name'] = user
		result['post_karma'] = get_user_post_karma
		result['comment_karma'] = get_user_comment_karma
		result['is_friend'] = @username ? is_friend : false
		result['moderating'] = get_moderating if is_moderator
		return result
	end

	#---------------------------------------------------------------------------------
	#User Activity handling
	#---------------------------------------------------------------------------------

  # Gets all the ativity divs from the currently open user
  #
  # @return [Array] an array including the divs
	def get_activity_divs
		divs = @browser.div(id: 'siteTable').children
		result = []
		divs.each do |div|
			result.push div if div.id.include? 'thing'
		end
		return result
	end

  # Gets the type of the activity
  #
  # @param div [Watir::Div] the activity's div
  # @return [String] the activity's type
	def get_activity_type(div)
		return div.attribute_value('data-type')
	end

  # Gets the link of the activity
  #
  # @param div [Watir::Div] the activity's div
  # @return [String] the activity's link
	def get_activity_link(div)
		return div.attribute_value('data-permalink')
	end

  # Gets the subreddit of the activity
  #
  # @param div [Watir::Div] the activity's div
  # @return [String] the activity's subreddit
	def get_activity_subreddit(div)
		return div.attribute_value('data-subreddit')
	end

  # Gets the title of the activity
  #
  # @param div [Watir::Div] the activity's div
  # @return [String] the activity's title
	def get_activity_title(div)
		return div.link(class: 'title').text
	end

  # Gets the activity's content if it is a comment
  #
  # @param div [Watir::Div] the activity's div
  # @return [String] the activity's text content
	def get_activity_content(div) #only for comments
		return div.div(class: 'usertext-body').text
	end

  # Gets the amount of karma the activity received, 'up', 'down' or overall
  #
  # @param div [Watir::Div] a div containing the activity
  # @param vote [String, nil] 'up' for number of upvotes, 'down' for downvotes, nil for total
  # @return [Integer] the number of votes/karma
	def get_activity_karma(div, vote)
		case get_activity_type(div)
		when 'comment' 
			return get_comment_karma(div, vote)
		when 'link'
			case vote
			when 'up' 
				return div.div(class: 'score likes').title.to_i
			when 'down' 
				return div.div(class: 'score dislikes').title.to_i
			else
				return div.div(class: 'score unvoted').title.to_i
			end
		else 
			raise 'Unknown activity type!'
		end
	end

  # Checks if the activity is voted by the logged in account, 'up' or 'down', raises an exception if an unknown vote type is submitted
  #
  # @param div [Watir::Div] a div containing the activity
  # @param type [String] the vote type, 'up' or 'down'
  # @return [Boolean] if the activity is voted
	def is_activity_voted(div, type)
		return is_comment_voted(div, type)
	end

  # Gets the activity's vote by the logged in account
  #
  # @param div [Watir::Div] a div containing the activity
  # @return [String, nil] 'up' if upvoted, 'down' if downvoted, nil if not voted
	def get_activity_vote(div)
		return get_comment_vote(div)
	end

  # Votes the given activity
  #
  # @param div [Watir::Div] a div containing the activity
  # @param [String] the vote type can be 'up' or 'down'
	def vote_activity(div, type)
		vote_message(div, type)
	end

  # Gets a hash containing information about the given activity
  #
  # @param div [Watir::Div] a div containing the activity
  # @return a hash containing information about the given activity
	def get_activity(div)
		result = {}
		result['type'] = get_activity_type(div)
		result['link'] = get_activity_link(div)
		result['subreddit'] = get_activity_subreddit(div)
		result['title'] = get_activity_title(div)
		result['content'] = result['type'] == 'link' ? result['title'] : get_activity_content(div)
		result['vote'] = get_activity_vote(div)
		result['karma'] = get_activity_karma(div, result['vote'])
		return result
	end

  # Moves to the next or previous page in the user's activity box
  #
  # @param direction [String] the direction to move, can be 'next' or 'prev'
  # @return [Boolean] returns true if moved to the desired page or false if didn't because you're already in the last (move next) or first (move prev) page
	def user_move_page(direction)
		return message_move_page(direction)
	end

  # Gets all the user activities from the given user, raises exception if unknown sorting method is used
  #
  # @param user [String] the username
  # @param sortby [String] sorting method, can be: 'new', 'hot', 'top', 'controversial'
  # @param max_pages [Integer] maximum amounts of pages to get activies from
  # @return [Array] an array containing all the activities hashes
	def get_user_activities(user, sortby = 'new', max_pages = 1)
		raise 'Unknown user sortby: ' + sortby if !USER_SORTBYS.include? sortby
		@browser.goto PAGE_USER + user + '/?sort=' + sortby
		result = []
		count = 0
		while true
			get_activity_divs.each do |div|
				result.push get_activity(div)
			end
			count += 1
			break if count >= max_pages
			break if !user_move_page('next')
		end
		return result
	end

	#---------------------------------------------------------------------------------
	#Extra functions
	#---------------------------------------------------------------------------------

  # Gets all the subreddits the currently logged user is banned in
  #
  # @return [Array] an array of strings containing the subreddits the user is banned in
	def get_banned_subreddits
		msgs = get_messages('messages', true)
		result = []
		msgs.each do |msg|
			result.push msg['author'] if msg['content'].include?('You have been permanently banned')
		end
		return result
	end

	def phase_pick_subs
		@browser.execute_script("var buttons = document.getElementsByClassName('c-btn c-btn-primary subreddit-picker__subreddit-button');\nfor (var i = 0; i < 8; i++) {\nbuttons[i].click();\n}")
	end

	def phase_enter_data(username, password, captcha_token)
		result = {}
		if username == nil
			link = @browser.link(class: 'username-generator__item')
			result['username'] = link.text
			link.click
		else
			result['username'] = username
			@browser.text_field(id: 'user_reg').set username
		end
		@browser.text_field(id: 'passwd_reg').set password
		result['password'] = password
		sleep 5
		@browser.execute_script(%{document.getElementById("g-recaptcha-response").innerHTML="} + captcha_token + %{"})
		sleep 5
		return result
	end

	def move_phase
		@browser.buttons(text: 'Submit').each do |button|
			if button.present?
				button.click
				sleep 5
				return
			end
		end
		@browser.buttons(text: 'Next').each do |button|
			if button.present?
				button.click
				sleep 5
				return
			end
		end
	end

	def get_phase
		return @browser.button(class: 'c-btn c-btn-primary subreddit-picker__subreddit-button').present? ? 'picksubs' : 'enterdata'
	end

  # Creates an account on reddit
  #
  # @param username [String] the account's username
  # @param password [String] the account's password
  # @param captcha_token [String] the google's captcha's token, it's up to you how to get it
  # @return [Hash] a hash containing the account's username and password
	def create_account(username, password, captcha_token) #if username is nil, selects username from reddit's suggestions
		@browser.goto PAGE_MAIN
		@browser.div(id: 'header-bottom-right').link(text: 'sign up').click
		sleep 3
		@browser.button(text: 'Next').click
		sleep 5
		result = nil
		2.times do
			case get_phase
			when 'picksubs'
				phase_pick_subs
			when 'enterdata'
				break if result != nil
				result = phase_enter_data(username, password, captcha_token)
			end
			move_phase
		end
		wait_login(result['username'])
		return result
	end

  # Checks if the given user is banned
  #
  # @param user [String] the username
  # @return [Boolean] whether the user is banned or not
	def is_user_banned(user)
		@browser.goto PAGE_USER + user
		skip_over_18 if has_over_18
		return @browser.div(id: 'classy-error').present? || @browser.h3(text: 'This account has been suspended').present?
	end

  # Checks if the given subreddit is banned
  #
  # @param subreddit [String] the subreddit's name
  # @return [Boolean] whether the subreddit is banned or not
	def is_subreddit_banned(subreddit)
		@browser.goto PAGE_SUBREDDIT + subreddit
		skip_over_18 if has_over_18
		return @browser.h3(text: 'This community has been banned').present?
	end
end