require 'tempfile'

require 'active_support/core_ext/object/blank.rb'
require 'active_support/core_ext/string/inflections'
require 'haml'
require 'mechanize'
require 'redis'
require 'redis/connection/hiredis'
require 'sinatra/base'

class Pokebot < Sinatra::Base
  attr_reader :redis

  def initialize
    @redis = Redis.new(url: ENV[ENV['REDIS_PROVIDER']])
    super
  end

  get '/' do
    pokes = redis.smembers('pokers').map do |id|
      name = redis.get("poker:#{id}:name")
      times = redis.get("poker:#{id}:times")
      OpenStruct.new(id: id, name: name, times: times)
    end.sort_by(&:times).reverse
    runs = redis.get('runs')
    haml :index, locals: { pokes: pokes, runs: runs }
  end
end

class Pokebot::Poller
  attr_reader :redis

  def initialize
    @redis = Redis.new(url: ENV[ENV['REDIS_PROVIDER']])
  end

  def poll
    agent = Mechanize.new

    cookies = redis.get('cookies')
    if cookies
      Tempfile.open(['cookies', '.yml']) do |file|
        file.write(cookies)
        file.rewind
        agent.cookie_jar.load(file.path)
      end
    else
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

      cookies = Tempfile.open(['cookies', '.yml']) do |file|
        agent.cookie_jar.save(file.path, session: true)
        file.rewind
        file.read
      end

      redis.set('cookies', cookies)
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
      redis.incr('runs')
      sleep (if ENV['INTERVAL'].present? then ENV['INTERVAL'].to_f else 5.0 end)
    end
  rescue => e
    $stderr.puts e
    $stderr.flush
    redis.del('cookies')
    sleep 30
    retry
  end
end
