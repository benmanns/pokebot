require 'mechanize'

agent = Mechanize.new

page = agent.get('https://m.facebook.com/')

page = page.form_with(id: 'login_form').tap do |form|
  form.email = ENV['FACEBOOK_EMAIL']
  form.pass = ENV['FACEBOOK_PASS']
end.submit

form = page.form_with(class: 'checkpoint')
if form
  page = form.submit(form.button_with(name: 'submit[Continue]'))
end

form = page.form_with(class: 'checkpoint')
if form
  page = form.submit(form.button_with(name: 'submit[This is Okay]'))
end

2.times do
  form = page.form_with(class: 'checkpoint')
  if form
    form.radiobutton_with(name: 'name_action_selected', value: 'dont_save').check
    page = form.submit(form.button_with(name: 'submit[Continue]'))
  end
end
