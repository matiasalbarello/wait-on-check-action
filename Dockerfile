FROM ruby:2.6.6-slim-buster
COPY entrypoint.rb /entrypoint.rb
COPY lib /lib
ENTRYPOINT ["/entrypoint.rb"]
