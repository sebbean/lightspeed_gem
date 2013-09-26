require "lightspeed/version"
require "httparty"
# require "rails"
# require "mongoid"


# path = File.join('.','config','mongoid.yml')
# puts path
# Mongoid.load!(path, :development)

HTTParty::Request.const_set('SupportedHTTPMethods', [
      Net::HTTP::Get,
      Net::HTTP::Post,
      Net::HTTP::Patch,
      Net::HTTP::Put,
      Net::HTTP::Delete,
      Net::HTTP::Head,
      Net::HTTP::Options,
      Net::HTTP::Move,
      Net::HTTP::Copy,
      Net::HTTP::Lock,
      Net::HTTP::Unlock
    ])
module Lightspeed
  class Filter

  end
  class Api
    include HTTParty

    attr_accessor :attributes, :id

    # headers 'Content-Encoding' => "x-gzip"
    headers "Content-Type"=> 'application/xml'
    headers 'Accept-Encoding'  => "deflate, gzip"
    format :xml
    http_proxy 'localhost', 8888

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
      if defined?(Rails)
        raw_config = File.read(File.join(Rails.root, 'config', path))
        env = Rails.env
      else
        raw_config = File.read(File.join('.', 'config', path))
        env = 'development'
      end

	    YAML.load(raw_config)[env]

  	end

    def initialize(config=nil)
      config ||= self.class.load_config_file 
      self.class.configure config
    end

    def self.lock(path, options={}, &block)
      perform_request Net::HTTP::Lock, path, options, &block      
    end
    def self.unlock(path, options={}, &block)
      perform_request Net::HTTP::Unlock, path, options, &block      
    end

    # hax but... wtf i guess
    def self.perform_request(http_method, path, options, &block) #:nodoc:
      configure load_config_file unless @configured

      table = self.to_s.downcase.split('::').last

      path = "/#{table}s#{path}" unless table == 'api'

      resp = super http_method, path, options, &block

       
      return resp if [Net::HTTP::Lock, Net::HTTP::Unlock].include? http_method

      resp = resp.parsed_response.values.first if resp.parsed_response.keys.count == 1

      if resp.keys.include? table
        resp = resp[table]
      end

      return resp if [Net::HTTP::Put, Net::HTTP::Post].include? http_method

      out = []
      if resp.kind_of?(Array)
        resp.map do |item|
          o = self.new 
          o.id = item['id']
          o.attributes = item
          out << o
        end
      elsif resp.kind_of?(Hash)
        out = self.new 
        out.id = resp['id']
        out.attributes = resp
      end

      out
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
      get '/', query: {count: 1, order_by: 'date_cre:desc'}
    end
    def self.first
      get '/', query: {count: 1, order_by: 'date_cre:asc'}
    end

    def self.since(time=nil)
      time ||= 1.days.ago
      filter "datetime_mod > \"#{time}\""
    end

    def self.filter(query, sort='datetime_mod:desc')
      get '/', query: {filter: "(#{query})"}#, order_by: sort}
    end

    def path
      "/#{File.join(table, id)}/"
    end

    def lock
      self.class.lock path
    end
    def unlock
      self.class.unlock path
    end
    def put
      self.attributes = self.class.put path, body: self.attribute_xml
    end
    def create
      self.attributes = self.class.create '/', body: self.attribute_xml
    end
    def table
      self.class.to_s.downcase.split('::').last
    end
    def attribute_xml
      self.attributes.to_xml(root: table, skip_instruct: true, indent: 0, dasherize: false)
    end

    def update
      lock
      resp = put 
      unlock

      resp
    end

    def create
      self.class.post '/', body: self.attribute_xml
    end
  end

  class Product < Api
    # attr_accessor :code, :description, 
    
    def self.find_by_code(code)
      filter "code contains[cd] \"#{code}\""
    end 
  end

  class Customer < Api

  end

  class Invoice < Api

  end

  class Lineitem < Invoice

  end

end
