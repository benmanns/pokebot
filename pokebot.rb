require 'active_support/core_ext/object/blank.rb'
require 'active_support/core_ext/string/inflections'
require 'haml'
require 'mechanize'
require 'redis'
require 'redis/connection/hiredis'
require 'sinatra'

redis = Redis.new(uri: ENV[ENV['REDIS_PROVIDER']])

Thread.new do
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
      id = poker_name.parameterize
      redis.sadd('pokers', id)
      redis.set("poker:#{id}:name", poker_name)
      times = redis.incr("poker:#{id}:times")
      $stdout.puts "Poked #{poker_name} #{times} times."
      $stdout.flush
    end
    sleep (ENV['INTERVAL'].to_f || 5.0)
  end
end

get '/' do
  pokes = redis.smembers('pokers').map do |id|
    name = redis.get("poker:#{id}:name")
    times = redis.get("poker:#{id}:times")
    OpenStruct.new(id: id, name: name, times: times)
  end.sort_by(&:times).reverse
  haml :index, locals: { pokes: pokes }
end

__END__

@@ layout
%html
  %head
    %title Pokebot
  %body
    %div.container
      %h1 Pokebot
      = yield

@@ index
- if pokes.present?
  %ul
    - pokes.each do |poke|
      %li Poked #{poke.name} #{poke.times} #{'time'.pluralize(poke.times)}.
- else
  %p No pokes yet.
