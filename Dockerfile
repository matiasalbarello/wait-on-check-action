FROM ruby:2.6.6-slim-buster

RUN mkdir /app
WORKDIR /app

COPY entrypoint.rb app/entrypoint.rb
COPY lib app/lib
ENTRYPOINT ["./app/entrypoint.rb"]
