require 'watir'

#Written by Ícaro Augusto
#Website: https://icaroaugusto.com
#Github: https://github.com/IcaroAugusto

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

	attr_accessor :browser
	attr_accessor :username

	def has_browser
		return @browser != nil
	end

	def is_logged_in(username)
		return @browser.link(text: username).present?
	end

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

	def login(username, password)
		@username = username
		@browser.goto PAGE_MAIN
		@browser.text_field(name: 'user').set username
		@browser.text_field(name: 'passwd').set password
		@browser.checkbox(id: 'rem-login-main').set
		@browser.button(text: 'login').click
		wait_login(username)
	end

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

	def logout
		@browser.link(text: 'logout').click
		wait_logout
	end

	def has_over_18
		return @browser.button(name: 'over18').present?
	end

	def skip_over_18
		@browser.button(text: 'continue').click
	end

	def has_over_18_new
		@browser.h3(text: 'You must be 18+ to view this community').present?
	end

	def skip_over_18_new
		@browser.link(text: 'Yes').click
	end

	#---------------------------------------------------------------------------------
	#Messages handling
	#---------------------------------------------------------------------------------

	def get_message_type(div)
		return div.attribute_value('data-type')
	end

	def get_message_post(div)
		return div.p(class: 'subject').link(class: 'title').href
	end

	def get_message_author(div)
		return div.attribute_value('data-author')
	end

	def get_message_subreddit(div)
		return div.attribute_value('data-subreddit')
	end

	def get_message_content(div)
		return div.div(class: 'md').text
	end

	def get_message_divs
		all_divs = @browser.div(id: 'siteTable').divs
		result = []
		all_divs.each do |div|
			result.push div if div.id.include? 'thing_'
		end
		return result
	end

	def is_message_voted(div, type) #type is 'up' or 'down'
		return div.div(class: 'midcol').div(class: type + 'mod').present?
	end

	def get_message_vote(div)
		return 'up' if is_message_voted(div, 'up')
		return 'down' if is_message_voted(div, 'down')
		return nil
	end

	def vote_message(div, type) #type is 'up' or 'down'
		return if is_message_voted(div, type)
		div.div(class: 'midcol').div(class: type).click
	end

	def reply_message(div, answer)
		div.li(text: 'reply').click
		div.textarea.set answer
		div.button(text: 'save').click
	end

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

	def message_move_page(direction) #directions: next for next page, prev for previous page
		button = @browser.span(class: direction + '-button')
		result = button.present?
		button.click if result
		return result
	end

	def open_messages_subpage(subpage)
		raise 'Unknown message subpage: ' + subpage if !MESSAGE_SUBPAGES.include? subpage
		@browser.goto PAGE_MESSAGES + subpage
	end

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

	def has_submit_error
		return @browser.span(text: 'you are doing that too much. try again in 9 minutes.').present?
	end

	def is_submit_open
		return @browser.textarea(name: 'title').present? || @browser.textarea(placeholder: 'Title').present?
	end

	def wait_submit
		count = 0.0
		while is_submit_open
			sleep 0.25
			count += 0.25
			raise 'Post submission failed!' if count >= 10
		end
	end

	def submit_link(subreddit, url, title)
		@browser.goto PAGE_SUBREDDIT + subreddit + '/submit'
		skip_over_18 if has_over_18
		@browser.text_field(id: 'url').set url
		@browser.textarea(name: 'title').set title
		@browser.button(name: 'submit').click
		wait_submit
	end

	def sub_has_flair
		return !@browser.div('aria-label': 'Not available for this community').present?
	end

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

	def get_original_post_vote
		return 'up' if is_original_post_voted('up')
		return 'down' if is_original_post_voted('down')
		return nil
	end

	def vote_original_post(type)
		return if is_original_post_voted(type)
		div = @browser.div(id: 'siteTable').div(class: 'midcol')
		div.div(class: type).click
	end

	def form_post_url(link)
		return PAGE_MAIN_NO_SLASH + link
	end

	def open_post(link)
		@browser.goto form_post_url(link)
	end

	def has_reply(answer)
		form = @browser.form(text: answer)
		return form.present? && form.parent.parent.attribute_value('data-author') == @username
	end

	def has_reply_error
		return @browser.span(class: 'error', style: '').present?
	end

	def get_reply_error
		return @browser.span(class: 'error', style: '').split(" ")[1]
	end

	def wait_reply(time = 2)
		sleep time
		return !has_reply_error
	end

	def reply_post(post, answer)
    case post.class
    when Hash
      @browser.goto PAGE_MAIN_NO_SLASH + post['link']
    when String
      @browser.goto post
    end
		@browser.div(class: 'commentarea').textarea(name: 'text').set answer
		@browser.div(class: 'commentarea').button(text: 'save').click
		return wait_reply
	end

	def get_comment_replies_count(div)
		return div.attribute_value('data-replies').to_i
	end

	def comment_has_replies(div)
		return div.attribute_value('data-replies') != '0'
	end

	def get_comment_author(div)
		return div.attribute_value('data-author')
	end

	def get_comment_link(div)
		return div.attribute_value('data-permalink')
	end

	def get_comment_content(div)
		return div.div(class: 'usertext-body').text
	end

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

	def is_comment_voted(div, type) #type is 'up' or 'down'
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

	def get_comment_vote(div)
		return 'up' if is_comment_voted(div, 'up')
		return 'down' if is_comment_voted(div, 'down')
		return nil
	end

	def comment_has_karma(div)
		return div.span(class: 'score').present?
	end

	def get_comment(div)
		result = {}
		result['author'] = get_comment_author(div)
		result['link'] = get_comment_link(div)
		result['content'] = get_comment_content(div)
		result['vote'] = get_comment_vote(div)
		result['karma'] = get_comment_karma(div, result['vote']) if comment_has_karma(div)
		return result
	end

	def get_comments_divs
		divs = @browser.div(class: 'commentarea').div(class: 'sitetable nestedlisting').children
		result = []
		divs.each do |div|
			result.push div if div.attribute_value('data-type') == 'comment'
		end
		return result
	end

	def get_replies_divs(main_div)
		divs = main_div.div(class: 'child').div.children
		begin #calling length if the length is 0 causes an exception
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

	def get_comments(post, expand = false)
		@browser.goto post
		expand_all_comments if expand
		return parse_comments_divs(get_comments_divs)
	end

	def reply_comments(div, answer)
		div.li(text: 'reply').click
		div.textarea(name: 'text').set answer
		div.button(class: 'save').click
	end

	def vote_comment(div, type)
		return if is_comment_voted(div, type)
		div.div(class: 'midcol').div(class: type).click
	end

	#---------------------------------------------------------------------------------
	#Subreddit handling
	#---------------------------------------------------------------------------------

	def get_posts_divs
		divs = @browser.div(id: 'siteTable').children
		result = []
		divs.each do |div|
			result.push div if div.attribute_value('data-type') == 'link'
		end
		return result
	end

	def get_post_author(div)
		return div.attribute_value('data-author')
	end

	def get_post_link(div)
		return div.attribute_value('data-permalink')
	end

	def get_post_karma(div)
		return div.attribute_value('data-score').to_i
	end

	def get_post_title(div)
		return div.link(class: 'title').text
	end

	def get_post_number_of_comments(div)
		return div.attribute_value('data-comments-count').to_i
	end

	def isPostVoted(div, type)
		return is_comment_voted(div, type)
	end

	def get_post_vote(div)
		return get_comment_vote(div)
	end

	def vote_post(div, type)
		vote_comment(div, type)
	end

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

	def subreddit_move_page(direction)
		return message_move_page(direction)
	end

	def open_subreddit(subreddit, subpage = 'hot')
		raise 'Unknown subreddit subpage: ' + subpage if !SUBREDDIT_SUBPAGES.include? subpage
		@browser.goto PAGE_SUBREDDIT + subreddit + '/' + subpage
	end

	def get_posts(subreddit, subpage = 'hot', max_pages = 1)
		raise 'Unknown subreddit subpage: ' + subpage if !SUBREDDIT_SUBPAGES.include? subpage
		@browser.goto PAGE_SUBREDDIT + subreddit + '/' + subpage
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

	def get_moderators(subreddit) #an array of user names, not user structs itself
		@browser.goto PAGE_SUBREDDIT + subreddit + '/about/moderators'
		spans = @browser.div(class: 'moderator-table').spans(class: 'user')
		result = []
		spans.each do |span|
			result.push span.link.text
		end
		return result
	end

	def get_subscribers
		return @browser.span(class: 'subscribers').span(class: 'number').text.gsub(',', '').to_i
	end

	def get_users_online
		return @browser.p(class: 'users-online').span(class: 'number').text.gsub(',', '').to_i
	end

	def get_side_bar
		return @browser.div(class: 'usertext-body').text
	end

	def get_subreddit(subreddit)
		result = {}
		result['name'] = subreddit
		@browser.goto PAGE_SUBREDDIT + subreddit
		result['subscribers'] = get_subscribers
		result['users_online'] = get_users_online
		result['sidebar'] = get_side_bar
		result['moderators'] = get_moderators(subreddit)
		return result
	end

	def did_create_sub
		return @browser.p(text: 'your subreddit has been created').present?
	end

	def wait_sub_creation
		count = 0.0
		while true
			return true if did_create_sub
			sleep 0.25
			count += 0.25
			return false if count >= 10
		end
	end

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

	def get_user_post_karma
		return @browser.span(class: 'karma').text.gsub(',', '').to_i
	end

	def get_user_comment_karma
		return @browser.spans(class: 'karma')[1].text.gsub(',', '').to_i
	end

	def is_moderator
		return @browser.ul(id: 'side-mod-list').present?
	end

	def get_moderating
		result = []
		@browser.ul(id: 'side-mod-list').lis.each do |li|
			result.push li.link.title.split('/')[1]
		end
		return result
	end

	def is_friend
		return @browser.span(class: 'fancy-toggle-button').link(text: '- friends').attribute_value('class').include?('active')
	end

	def add_friend
		return if is_friend
		@browser.link(text: '+ friends').click
	end

	def remove_friend
		return if !is_friend
		@browser.link(text: '- friends').click
	end

	def open_user_page(user)
		@browser.goto PAGE_USER + user
		skip_over_18 if has_over_18
	end

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

	def get_activity_divs
		divs = @browser.div(id: 'siteTable').children
		result = []
		divs.each do |div|
			result.push div if div.id.include? 'thing'
		end
		return result
	end

	def get_activity_type(div)
		return div.attribute_value('data-type')
	end

	def get_activity_link(div)
		return div.attribute_value('data-permalink')
	end

	def get_activity_subreddit(div)
		return div.attribute_value('data-subreddit')
	end

	def get_activity_title(div)
		return div.link(class: 'title').text
	end

	def get_activity_content(div) #only for comments
		return div.div(class: 'usertext-body').text
	end

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

	def is_activity_voted(div, type)
		return is_comment_voted(div, type)
	end

	def get_activity_vote(div)
		return get_comment_vote(div)
	end

	def vote_activity(div, type)
		vote_message(div, type)
	end

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

	def user_move_page(direction)
		return message_move_page(direction)
	end

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

	def is_user_banned(user)
		@browser.goto PAGE_USER + user
		skip_over_18 if has_over_18
		return @browser.div(id: 'classy-error').present? || @browser.h3(text: 'This account has been suspended').present?
	end

	def is_subreddit_banned(subr)
		@browser.goto PAGE_SUBREDDIT + subr
		skip_over_18 if has_over_18
		return @browser.h3(text: 'This community has been banned').present?
	end
end