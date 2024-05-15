#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "owl"
require "sinatra"
require "sinatra/json"
require "sinatra/namespace"
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

    get "/" do
      redirect 'index.html'
    end

    get "/sidebar" do
      slim :sidebar, :forum => @forum
    end

    get "/details" do
      slim :details
    end

    get "/content" do
      slim :content
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
