require "lightspeed/version"
require "httparty"
require "rails"

module Lightspeed
  # Your code goes here...
  class Api
    include HTTParty

    headers 'Content-Encoding' => "x-gzip"
    headers 'Accept-Encoding'  => "deflate, gzip"

    @configured = false
    def self.configure(config)
      base_uri "#{config[:endpoint]}/api/"
      basic_auth config[:username], config[:password]
      headers 'User-Agent'       => config[:user_agent]
      headers 'X-PAPPID'         => config[:app_id]
      headers 'Cookie'           => config[:cookie] unless config[:cookie].nil?
      @configured = true
    end

  	def self.load_config_file(path="lightspeed.yml")
      base = Rails.root || '.'
      raw_config = File.read(File.join(base, 'config', path))
	    YAML.load(raw_config)[Rails.env].symbolize_keys 
  	end

    def initialize(config=nil)
      config ||= self.class.load_config_file 
      self.class.configure config
    end

    # hax but... wtf i guess
    def self.perform_request(http_method, path, options, &block) #:nodoc:
      configure load_config_file unless @configured

      table = self.to_s.downcase.split('::').last
      path = "/#{table}s#{path}" 

      resp = super http_method, path, options, &block
      resp = resp.parsed_response.values.first if resp.parsed_response.keys.count == 1
      return resp unless resp 
      resp = resp.values.first if resp.keys.count == 1 
      return resp if resp.kind_of?(Array)
      resp = resp.values.first if resp.keys.count == 2 && resp.keys.last.match('total_count')

      resp
    end

    def self.logout
      post '/sessions/current/logout/'
    end

    def self.users
      get '/users/', query: { count: 1, order_by: 'id:asc' }
    end

    def self.find(id=1)
      get "/#{id}/"
    end

    def self.last
      get '/', query: {count: 1}
    end

    def self.since(time=nil)
      time ||= 1.days.ago
      filter "date_mod > \"#{time}\""
    end

    def self.filter(query)
      get '/', query: {filter: "(#{query})"}
    end
  end

  class Product < Api
    def self.find_by_code(code)
      filter "code contains[cd] \"#{code}\""
    end 
  end


  class Invoice < Api

  end
end
