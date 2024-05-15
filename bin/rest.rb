#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "owl"
require "sinatra"
require "sinatra/json"
require "sinatra/namespace"

module OwlApi
  class App < Sinatra::Base
    register Sinatra::Namespace

    def initialize
      @forum = Owl::Forum.new("/var/lib/owl/the13")
    end

    configure do
      set :reload_templates, false
    end

    before do
      content_type :json
    end

    namespace '/api/v1' do
      get '/contents' do
        json @forum
      end
    end
  end
end

OwlApi::App.run!
