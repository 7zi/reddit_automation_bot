
require 'watir'

#Written by Ícaro Augusto
#Website: https://icaroaugusto.com
#Github: https://github.com/IcaroAugusto

TRedditMessage = Struct.new(
	:type, #'comment' or 'message'
	:author, #who sent the message, if comment, the user else the subreddit
	:post, #if a comment, the post that contains the comment, else nil
	:subreddit, #if is a comment, the subreddit of the post, else the subreddit itself
)

TRedditComment = Struct.new(
	:author, #who posted the comment
	:link, #a direct link to the comment
	:karma, #comment's karma
	:content, #the comment's content
	:vote, #did the account vote on the comment? upvote or downvote or nil
	:replies #all the replies to the comment (array of comments)
)

TRedditPost = Struct.new(
	:author,
	:link,
	:karma,
	:title,
	:vote,
	:numberComments
)

TRedditUser = Struct.new(
	:name,
	:postKarma,
	:commentKarma,
	:moderating, #subreddits the user is a moderator of
	:isFriend
)

TSubreddit = Struct.new(
	:name,
	:subscribers,
	:usersOnline,
	:sidebar,
	:moderators
)

TNewSub = Struct.new(
	:name,
	:title,
	:description,
	:sidebar,
	:subtext,
	:type,
	:content
)

TRedditUserActivity = Struct.new(
	:type, #link or comment
	:link, #link to the activity
	:subreddit, #the subreddit in which the activity ocurred
	:title,
	:content,
	:karma,
	:vote
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

	attr_accessor :browser
	attr_accessor :username

	def hasBrowser
		return @browser != nil
	end

	def isLoggedIn(username)
		return @browser.link(text: username).present?
	end

	def waitLogin(username)
		count = 0.0
		while !isLoggedIn(username)
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
		waitLogin(username)
	end

	def waitLogout
		count = 0.0
		while isLoggedIn(@username)
			sleep 0.25
			count += 0.25
			if count > 10
				raise 'Reddit logout failed for username: ' + @username
			end
		end
	end

	def logout
		@browser.link(text: 'logout').click
		waitLogout
	end

	def hasOver18
		return @browser.button(name: 'over18').present?
	end

	def skipOver18
		@browser.button(text: 'continue').click
	end

	def hasOver18New
		@browser.h3(text: 'You must be 18+ to view this community').present?
	end

	def skipOver18New
		@browser.link(text: 'Yes').click
	end

	#---------------------------------------------------------------------------------
	#Messages handling
	#---------------------------------------------------------------------------------

	def getMessageType(div)
		return div.attribute_value('data-type')
	end

	def getMessagePost(div)
		return div.p(class: 'subject').link(class: 'title').href
	end

	def getMessageAuthor(div)
		return div.attribute_value('data-author')
	end

	def getMessageSubreddit(div)
		return div.attribute_value('data-subreddit')
	end

	def getMessageContent(div)
		return div.div(class: 'md').text
	end

	def getMessagesDivs
		allDivs = @browser.div(id: 'siteTable').divs
		result = []
		allDivs.each do |div|
			result.push div if div.id.include? 'thing_'
		end
		return result
	end

	def isMessageVoted(div, type) #type is 'up' or 'down'
		return div.div(class: 'midcol').div(class: type + 'mod').present?
	end

	def getMessageVote(div)
		return 'up' if isMessageVoted(div, 'up')
		return 'down' if isMessageVoted(div, 'down')
		return nil
	end

	def voteMessage(div, type) #type is 'up' or 'down'
		return if isMessageVoted(div, type)
		div.div(class: 'midcol').div(class: type).click
	end

	def replyMessage(div, answer)
		div.li(text: 'reply').click
		div.textarea.set answer
		div.button(text: 'save').click
	end

	def getMessage(div) #returns a hash with message data
		result = {}
		result['type'] = getMessageType(div)
		result['author'] = getMessageAuthor(div)
		result['post'] = getMessagePost(div) if result['type'] == 'comment'
		result['subreddit'] = result['type'] == 'comment' ? getMessageSubreddit(div) : result['author']
		result['vote'] = getMessageVote(div) if result['type'] == 'comment'
		result['content'] = getMessageContent(div)
		return result
	end

	def messageMovePage(direction) #directions: next for next page, prev for previous page
		button = @browser.span(class: direction + '-button')
		result = button.present?
		button.click if result
		return result
	end

	def openMessagesSubpage(subpage)
		raise 'Unknown message subpage: ' + subpage if !MESSAGE_SUBPAGES.include? subpage
		@browser.goto PAGE_MESSAGES + subpage
	end

	def getMessages(subpage, allPages = false)
		openMessagesSubpage(subpage)
		result = []
		while true
			getMessagesDivs.each do |div|
				result.push getMessage(div)
			end
			return result if !allPages || !messageMovePage('next')
		end
	end

	#---------------------------------------------------------------------------------
	#Submit handling
	#---------------------------------------------------------------------------------

	def hasSubmitError
		return @browser.span(text: 'you are doing that too much. try again in 9 minutes.').present?
	end

	def isSubmitOpen
		return @browser.textarea(name: 'title').present? || @browser.textarea(placeholder: 'Title').present?
	end

	def waitSubmit
		count = 0.0
		while isSubmitOpen
			sleep 0.25
			count += 0.25
			raise 'Post submission failed!' if count >= 10
		end
	end

	def submitLink(subreddit, url, title)
		@browser.goto PAGE_SUBREDDIT + subreddit + '/submit'
		skipOver18 if hasOver18
		@browser.text_field(id: 'url').set url
		@browser.textarea(name: 'title').set title
		@browser.button(name: 'submit').click
		waitSubmit
	end

	def subHasFlair
		return !@browser.div('aria-label': 'Not available for this community').present?
	end

	def setFlair(flair)
		return if !subHasFlair
		@browser.div('aria-label': 'Add flair').click
		if flair == nil
			@browser.div('aria-label': 'flair_picker').div.click
		else
			@browser.div('aria-label': 'flair_picker').span(text: flair).click
		end
		@browser.button(text: 'Apply').click
	end

	def submitLink2(subreddit, url, title, flair = nil) #uses new reddit
		@browser.goto 'https://www.reddit.com/r/' + subreddit + '/submit'
		skipOver18New if hasOver18New
		blink = @browser.button(text: 'Link')
		blink.click if blink.present?
		@browser.textarea(placeholder: 'Title').set title
		@browser.textarea(placeholder: 'Url').set url
		setFlair(flair)
		@browser.buttons(text: 'Post')[1].click
		waitSubmit
	end

	def submitText(subreddit, title, text)
		@browser.goto PAGE_SUBREDDIT + subreddit + '/submit?selftext=true'
		skipOver18 if hasOver18
		@browser.textarea(name: 'title').set title
		@browser.textarea(name: 'text').set text
		@browser.button(name: 'submit').click
		waitSubmit
	end

	#---------------------------------------------------------------------------------
	#Post handling
	#---------------------------------------------------------------------------------

	def isOriginalPostVoted(type)
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

	def getOriginalPostVote
		return 'up' if isOriginalPostVoted('up')
		return 'down' if isOriginalPostVoted('down')
		return nil
	end

	def voteOriginalPost(type)
		return if isOriginalPostVoted(type)
		div = @browser.div(id: 'siteTable').div(class: 'midcol')
		div.div(class: type).click
	end

	def formPostUrl(link)
		return PAGE_MAIN_NO_SLASH + link
	end

	def openPost(link)
		@browser.goto formPostUrl(link)
	end

	def hasReply(answer)
		form = @browser.form(text: answer)
		return form.present? && form.parent.parent.attribute_value('data-author') == @username
	end

	def hasReplyError
		return @browser.span(class: 'error', style: '').present?
	end

	def getReplyError
		return @browser.span(class: 'error', style: '').split(" ")[1]
	end

	def waitReply(time = 2)
		sleep time
		return !hasReplyError
	end

	def replyPost(post, answer)
		@browser.goto post if post != nil
		@browser.div(class: 'commentarea').textarea(name: 'text').set answer
		@browser.div(class: 'commentarea').button(text: 'save').click
		return waitReply
	end

	def getCommentRepliesCount(div)
		return div.attribute_value('data-replies').to_i
	end

	def commentHasReplies(div)
		return div.attribute_value('data-replies') != '0'
	end

	def getCommentAuthor(div)
		return div.attribute_value('data-author')
	end

	def getCommentLink(div)
		return div.attribute_value('data-permalink')
	end

	def getCommentContent(div)
		return div.div(class: 'usertext-body').text
	end

	def getCommentKarma(div, vote)
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

	def isCommentVoted(div, type) #type is 'up' or 'down'
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

	def getCommentVote(div)
		return 'up' if isCommentVoted(div, 'up')
		return 'down' if isCommentVoted(div, 'down')
		return nil
	end

	def commentHasKarma(div)
		return div.span(class: 'score').present?
	end

	def getComment(div)
		result = {}
		result['author'] = getCommentAuthor(div)
		result['link'] = getCommentLink(div)
		result['content'] = getCommentContent(div)
		result['vote'] = getCommentVote(div)
		result['karma'] = getCommentKarma(div, result['vote']) if commentHasKarma(div)
		return result
	end

	def getCommentsDivs
		divs = @browser.div(class: 'commentarea').div(class: 'sitetable nestedlisting').children
		result = []
		divs.each do |div|
			result.push div if div.attribute_value('data-type') == 'comment'
		end
		return result
	end

	def getRepliesDivs(mainDiv)
		divs = mainDiv.div(class: 'child').div.children
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

	def parseCommentsDivs(divs)
		result = []
		divs.each do |div|
			result.push getComment(div)
			if commentHasReplies(div)
				result[result.length-1]['replies'] = parseCommentsDivs(getRepliesDivs(div))
			end
		end
		return result
	end

	def expandAllComments
		while true
			begin
				span = @browser.span(class: 'morecomments')
				span.present? ? span.click : return
			rescue
			end
			sleep 0.5
		end
	end

	def getComments(post, expand = false)
		@browser.goto post
		expandAllComments if expand
		return parseCommentsDivs(getCommentsDivs)
	end

	def replyComment(div, answer)
		div.li(text: 'reply').click
		div.textarea(name: 'text').set answer
		div.button(class: 'save').click
	end

	def voteComment(div, type)
		return if isCommentVoted(div, type)
		div.div(class: 'midcol').div(class: type).click
	end

	#---------------------------------------------------------------------------------
	#Subreddit handling
	#---------------------------------------------------------------------------------

	def getPostsDivs
		divs = @browser.div(id: 'siteTable').children
		result = []
		divs.each do |div|
			result.push div if div.attribute_value('data-type') == 'link'
		end
		return result
	end

	def getPostAuthor(div)
		return div.attribute_value('data-author')
	end

	def getPostLink(div)
		return div.attribute_value('data-permalink')
	end

	def getPostKarma(div)
		return div.attribute_value('data-score').to_i
	end

	def getPostTitle(div)
		return div.link(class: 'title').text
	end

	def getPostNumberComments(div)
		return div.attribute_value('data-comments-count').to_i
	end

	def isPostVoted(div, type)
		return isCommentVoted(div, type)
	end

	def getPostVote(div)
		return getCommentVote(div)
	end

	def votePost(div, type)
		voteComment(div, type)
	end

	def getPost(div)
		result = {}
		result['author'] = getPostAuthor(div)
		result['link'] = getPostLink(div)
		result['karma'] = getPostKarma(div)
		result['title'] = getPostTitle(div)
		result['vote'] = getPostVote(div)
		result['numberComments'] = getPostNumberComments(div)
		return result
	end

	def subredditMovePage(direction)
		return messageMovePage(direction)
	end

	def openSubreddit(subreddit, subpage = 'hot')
		raise 'Unknown subreddit subpage: ' + subpage if !SUBREDDIT_SUBPAGES.include? subpage
		@browser.goto PAGE_SUBREDDIT + subreddit + '/' + subpage
	end

	def getPosts(subreddit, subpage = 'hot', maxPages = 1)
		raise 'Unknown subreddit subpage: ' + subpage if !SUBREDDIT_SUBPAGES.include? subpage
		@browser.goto PAGE_SUBREDDIT + subreddit + '/' + subpage
		result = []
		count = 0
		while true
			getPostsDivs.each do |div|
				result.push getPost(div)
			end
			count += 1
			break if count >= maxPages
			break if !subredditMovePage('next')
		end
		return result
	end

	def getModerators(subreddit) #an array of user names, not user structs itself
		@browser.goto PAGE_SUBREDDIT + subreddit + '/about/moderators'
		spans = @browser.div(class: 'moderator-table').spans(class: 'user')
		result = []
		spans.each do |span|
			result.push span.link.text
		end
		return result
	end

	def getSubscribers
		return @browser.span(class: 'subscribers').span(class: 'number').text.gsub(',', '').to_i
	end

	def getUsersOnline
		return @browser.p(class: 'users-online').span(class: 'number').text.gsub(',', '').to_i
	end

	def getSidebar
		return @browser.div(class: 'usertext-body').text
	end

	def getSubreddit(subreddit)
		result = {}
		result['name'] = subreddit
		@browser.goto PAGE_SUBREDDIT + subreddit
		result['subscribers'] = getSubscribers
		result['usersOnline'] = getUsersOnline
		result['sidebar'] = getSidebar
		result['moderators'] = getModerators(subreddit)
		return result
	end

	def didCreateSub
		return @browser.p(text: 'your subreddit has been created').present?
	end

	def waitSubCreation
		count = 0.0
		while true
			return true if didCreateSub
			sleep 0.25
			count += 0.25
			return false if count >= 10
		end
	end

	def createSubreddit(subreddit)
		@browser.goto CREATE_SUB_PAGE
		@browser.text_field(id: 'name').set subreddit.name
		@browser.text_field(id: 'title').set subreddit.title
		@browser.textarea(name: 'public_description').set subreddit.description
		@browser.textarea(name: 'description').set subreddit.sidebar
		@browser.textarea(name: 'submit_text').set subreddit.subtext
		@browser.radio(id: SUB_TYPES[subreddit.type]).set
		@browser.radio(id: CONTENT_OPTIONS[subreddit.content]).set
		@browser.button(text: 'create').click
		return waitSubCreation
	end

	#---------------------------------------------------------------------------------
	#User handling
	#---------------------------------------------------------------------------------

	def getUserPostKarma
		return @browser.span(class: 'karma').text.gsub(',', '').to_i
	end

	def getUserCommentKarma
		return @browser.spans(class: 'karma')[1].text.gsub(',', '').to_i
	end

	def isModerator
		return @browser.ul(id: 'side-mod-list').present?
	end

	def getModerating
		result = []
		@browser.ul(id: 'side-mod-list').lis.each do |li|
			result.push li.link.title.split('/')[1]
		end
		return result
	end

	def isFriend
		return @browser.span(class: 'fancy-toggle-button').link(text: '- friends').attribute_value('class').include?('active')
	end

	def addFriend
		return if isFriend
		@browser.link(text: '+ friends').click
	end

	def removeFriend
		return if !isFriend
		@browser.link(text: '- friends').click
	end

	def openUserPage(user)
		@browser.goto PAGE_USER + user
		skipOver18 if hasOver18
	end

	def getUser(user)
		openUserPage(user)
		return nil if @browser.div(id: 'classy-error').present?
		result = {}
		result['name'] = user
		result['postKarma'] = getUserPostKarma
		result['commentKarma'] = getUserCommentKarma
		result['isFriend'] = @username ? isFriend : false
		result['moderating'] = getModerating if isModerator
		return result
	end

	#---------------------------------------------------------------------------------
	#User Activity handling
	#---------------------------------------------------------------------------------

	def getActivityDivs
		divs = @browser.div(id: 'siteTable').children
		result = []
		divs.each do |div|
			result.push div if div.id.include? 'thing'
		end
		return result
	end

	def getActivityType(div)
		return div.attribute_value('data-type')
	end

	def getActivityLink(div)
		return div.attribute_value('data-permalink')
	end

	def getActivitySubreddit(div)
		return div.attribute_value('data-subreddit')
	end

	def getActivityTitle(div)
		return div.link(class: 'title').text
	end

	def getActivityContent(div) #only for comments
		return div.div(class: 'usertext-body').text
	end

	def getActivityKarma(div, vote)
		case getActivityType(div)
		when 'comment' 
			return getCommentKarma(div, vote)
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

	def isActivityVoted(div, type)
		return isCommentVoted(div, type)
	end

	def getActivityVote(div)
		return getCommentVote(div)
	end

	def voteActivity(div, type)
		voteMessage(div, type)
	end

	def getActivity(div)
		result = {}
		result['type'] = getActivityType(div)
		result['link'] = getActivityLink(div)
		result['subreddit'] = getActivitySubreddit(div)
		result['title'] = getActivityTitle(div)
		result['content'] = result['type'] == 'link' ? result['title'] : getActivityContent(div)
		result['vote'] = getActivityVote(div)
		result['karma'] = getActivityKarma(div, result['vote'])
		return result
	end

	def userMovePage(direction)
		return messageMovePage(direction)
	end

	def getUserActivities(user, sortby = 'new', maxPages = 1)
		raise 'Unknown user sortby: ' + sortby if !USER_SORTBYS.include? sortby
		@browser.goto PAGE_USER + user + '/?sort=' + sortby
		result = []
		count = 0
		while true
			getActivityDivs.each do |div|
				result.push getActivity(div)
			end
			count += 1
			break if count >= maxPages
			break if !userMovePage('next')
		end
		return result
	end

	#---------------------------------------------------------------------------------
	#Extra functions
	#---------------------------------------------------------------------------------

	def getBannedSubreddits
		msgs = getMessages('messages', true)
		result = []
		msgs.each do |msg|
			result.push msg['author'] if msg['content'].include?('You have been permanently banned')
		end
		return result
	end

	def phasePickSubs
		@browser.execute_script("var buttons = document.getElementsByClassName('c-btn c-btn-primary subreddit-picker__subreddit-button');\nfor (var i = 0; i < 8; i++) {\nbuttons[i].click();\n}")
	end

	def phaseEnterData(username, password, captchaToken)
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
		@browser.execute_script(%{document.getElementById("g-recaptcha-response").innerHTML="} + captchaToken + %{"})
		sleep 5
		# puts 'Press enter after captcha is solved.'
		# gets
		return result
	end

	def movePhase
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

	def getPhase
		return @browser.button(class: 'c-btn c-btn-primary subreddit-picker__subreddit-button').present? ? 'picksubs' : 'enterdata'
	end

	def createAccount(username, password, captchaToken) #if username is nil, selects username from reddit's suggestions
		@browser.goto PAGE_MAIN
		@browser.div(id: 'header-bottom-right').link(text: 'sign up').click
		sleep 3
		@browser.button(text: 'Next').click
		sleep 5
		result = nil
		2.times do
			case getPhase
			when 'picksubs'
				phasePickSubs
			when 'enterdata'
				break if result != nil
				result = phaseEnterData(username, password, captchaToken)
			end
			movePhase
		end
		waitLogin(result['username'])
		return result
	end

	def isUserBanned(user)
		@browser.goto PAGE_USER + user
		skipOver18 if hasOver18
		return @browser.div(id: 'classy-error').present? || @browser.h3(text: 'This account has been suspended').present?
	end

	def isSubBanned(subr)
		@browser.goto PAGE_SUBREDDIT + subr
		skipOver18 if hasOver18
		return @browser.h3(text: 'This community has been banned').present?
	end
end