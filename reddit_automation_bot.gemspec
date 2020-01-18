Gem::Specification.new do |s|
  s.name = 'reddit_automation_bot'
  s.version = "1.0.0"
  s.date = '2020-01-18'
  s.required_ruby_version = '>= 2.3.0'
  s.summary = 'A reddit automation gem that uses watir/selenium'
  s.description = 'This gem uses watir and selenium to automate almost all reddit features using a headless browser.'
  s.files = [
    "lib/reddit.rb"
  ]
  s.require_paths = ["lib"]
  s.add_dependency 'watir'
  s.license = 'MIT'
  s.email = ['icaro10100@hotmail.com']
end