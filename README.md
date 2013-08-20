# Pokebot

Pokebot logs into Facebook on your behalf and pokes back people who have poked you.

You can run Pokebot as a free Heroku app.

```sh
heroku create
heroku config:set FACEBOOK_EMAIL="user@example.com" FACEBOOK_PASSWORD="hunter2"
heroku addons:add redistogo:nano
heroku config:set REDIS_PROVIDER=REDISTOGO_URL
git push heroku master
```

Then, watch your Facebook session carefully, because the Heroku session usually looks like a suspicious new device, so approve it as soon as you see the message.
