require './pokebot.rb'

poller = Pokebot::Poller.new
Thread.new { poller.poll }
run Pokebot
