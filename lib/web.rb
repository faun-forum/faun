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
  class App < Sinatra::Base
    def initialize
      super
      @forum = Faun::Forum.new("/var/lib/faun/the13")
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

    def active_from(select = nil)
      a = {
        :topic => params["topic"] || @forum.defaults["topic"]
      }
      a.merge!(
        :thread =>  params["thread"],
        :comment =>  params["comment"]
      )
      a[:post] = params["post"] || (
        a[:topic] ? @forum.topic_from(a[:topic]).posts.keys.first : @forum.defaults["post"]
      )
      a[:post] ||= @forum.posts.keys.first
      select ? a[select] : a
    end

    get "/" do
      slim :index, { :locals => { :active => active_from } }
    end

    get "/topics/" do
      slim :sidebar, { :locals => { :active => params["active"] } }
    end

    get "/topics/:id/" do |id|
      topic = @forum.topic(id.to_i)
      slim :details, :locals => { :posts => topic.posts, :active => active_from(:post), :topic => "#{id}" }
    end

    get "/topics/:id/:subid/" do |id, subid|
      sub = @forum.subtopic(id.to_i, subid.to_i)
      slim :details, :locals => { :posts => sub.posts, :active => active_from(:post), :topic => "#{id}.#{subid}" }
    end

    get "/posts/" do
      slim :details, :locals => { :posts => @forum.posts, :active => active_from(:post), :topic => nil }
    end

    get "/posts/:id/" do |id|
      post = @forum.post(id.to_i)
      content = Kramdown::Document.new(post.content).to_html
      contents = params["contents"] == "true"
      discussion = params["discussion"].nil? ? true : params["discussion"] == "true"
      slim :content, :locals => {
        :post => post,
        :content => content,
        :contents => contents,
        :discussion => discussion,
        :active => active_from(:thread) || post.threads.keys.first.to_s
      }
    end

    get "/posts/:id/assets/:name" do |id, name|
      post = @forum.post(id.to_i)
      asset_path = post.asset_path(name)
      content_type MIME::Types.type_for(asset_path).first.content_type
      send_file asset_path
    end

    get "/posts/:id/threads/" do |id|
      post = @forum.post(id.to_i)
      thread = post.threads.values.first
      slim :thread, :locals => { :thread => thread, :active => active_from(:thread) }
    end

    get "/posts/:id/threads/:tid/" do |id, tid|
      post = @forum.post(id.to_i)
      thread = post.threads[tid.to_i]
      slim :thread, :locals => { :thread => thread, :active => active_from(:comment) }
    end
  end
end
