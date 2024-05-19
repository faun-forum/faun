# frozen_string_literal: true

require "bundler/setup"
require "sinatra"
require "sinatra/json"
require "sinatra/namespace"
require "kramdown"
require 'mime/types'
require "logger"

require_relative "model"

module FaunWeb
  class App
    register Sinatra::Namespace

    namespace '/api/v1' do
      before do
        content_type :json
      end

      get '/topics' do
        json @forum
      end

      get '/topics/:id' do |id|
        topic = @forum.topic(id.to_i)
        topic.posts_json
      end

      get '/topics/:id/:subid' do |id, subid|
        sub = @forum.subtopic(id.to_i, subid.to_i)
        sub.posts_json
      end

      get '/posts' do
        @forum.posts_json
      end

      get '/posts/:id' do |id|
        post = @forum.post(id.to_i)
        post.to_json
      end
    end
  end
end
