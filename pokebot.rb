require 'mechanize'

pokes = Hash.new(0)

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

loop do
  page = agent.get('https://m.facebook.com/pokes')
  page.search('#root .poke').each do |poke|
    poke_back = poke.search('a[href^="/a/notifications.php?poke="]').first
    poke_back_href = poke_back.attributes['href'].value
    poker_name = poke.search('.pokerName').first.text
    agent.get(poke_back_href)
    pokes[poker_name] += 1
    puts "Poked #{poker_name} #{pokes[poker_name]} times."
  end
  sleep (ENV['INTERVAL'].to_f || 5.0)
end
