FROM ruby:2.6.6-slim-buster

COPY entrypoint.rb /entrypoint.rb
COPY models /models
ENTRYPOINT ["/entrypoint.rb"]
