#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "owl"
require "sinatra"
require "sinatra/json"
require "sinatra/namespace"
require "kramdown"
require "logger"

module OwlApi
  class App < Sinatra::Base
    register Sinatra::Namespace

    def initialize
      super
      @forum = Owl::Forum.new("/var/lib/owl/the13")
    end

    configure do
      enable :static
      set :views, File.expand_path("../views", __dir__)
      set :public_folder, File.expand_path("../public", __dir__)
    end

    configure :development do
      enable :logging, :dump_errors, :raise_errors
      set :logging, Logger::DEBUG
    end

    before :development do
      cache_control :no_store, :no_cache, :must_revalidate
    end

    get "/" do
      redirect 'index.html'
    end

    get "/sidebar" do
      slim :sidebar
    end

    get "/posts/:id/:subid" do |id, subid|
      sub = @forum.subtopic(id.to_i, subid.to_i)
      slim :details, :locals => { :posts => sub.items }
    end

    get "/post/:id" do |id|
      post = @forum.post(id.to_i)
      content = Kramdown::Document.new(post.content).to_html
      slim :content, :locals => { :post => post, :content => content }
    end

    namespace '/api/v1' do
      before do
        content_type :json
      end

      get '/contents' do
        json @forum
      end
    end
  end
end

OwlApi::App.run!
