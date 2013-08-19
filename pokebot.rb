require 'mechanize'

agent = Mechanize.new

page = agent.get('https://m.facebook.com/')

page = page.form_with(id: 'login_form').tap do |form|
  form.email = ENV['FACEBOOK_EMAIL']
  form.pass = ENV['FACEBOOK_PASS']
end.submit
