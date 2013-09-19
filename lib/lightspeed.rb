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

      puts "configggging"
    end

  	def self.load_config_file(path="lightspeed.yml")
      raw_config = File.read(path)
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

      puts path
      options = default_options.dup.merge(options)
      process_cookies(options)

      resp = Request.new(http_method, path, options).perform(&block)
    
      resp = resp.parsed_response.values.first if resp.parsed_response.keys.count == 1
      resp = resp.values.first if resp.keys.count == 1

      # headers 'Cookie' => resp.headers['set-cookie'].first unless @@configured
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
  end

  class Product < Api
    def self.find_by_code(code)
      filter = "(code contains[cd] \"#{code}\")"
      get '/', query: {filter: filter}
    end 
  end


  class Invoice < Api

  end
end
