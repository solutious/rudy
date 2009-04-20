
require 'time'
require 'cgi'
require 'uri'
require 'net/http'
require 'base64'
require 'openssl'
require 'rexml/document'
require 'rexml/xpath'

module Rudy
  module AWS
    class SDB
      class NoAccessKey < RuntimeError; end
      class NoSecretKey < RuntimeError; end
        
      require 'rudy/aws/sdb/error'
      
      def initialize(access_key=nil, secret_key=nil, region=nil, debug=nil)
        raise NoAccessKey if access_key.nil? || access_key.empty?
        raise NoSecretKey if secret_key.nil? || secret_key.empty?
          
        url ||= 'http://sdb.amazonaws.com'
        # There is a bug with passing :server to EC2::Base.new so 
        # we'll use the environment variable for now. 
        #if region && Rudy::AWS.valid_region?(region)
        #  "#{region}.sdb.amazonaws.com"
        #end
        
        @access_key_id = access_key || ENV['AWS_ACCESS_KEY']
        @secret_access_key = secret_key || ENV['AWS_SECRET_KEY']
        @base_url = url
        @debug = debug || StringIO.new
      end

      def list_domains(max = nil, token = nil)
        params = { 'Action' => 'ListDomains' }
        params['NextToken'] =
          token unless token.nil? || token.empty?
        params['MaxNumberOfDomains'] =
          max.to_s unless max.nil? || max.to_i == 0
        doc = call(:get, params)
        results = []
        REXML::XPath.each(doc, '//DomainName/text()') do |domain|
          results << domain.to_s
        end
        #return results, REXML::XPath.first(doc, '//NextToken/text()').to_s
        results
      end

      def create_domain(domain)
        call(:post, { 'Action' => 'CreateDomain', 'DomainName'=> domain.to_s })
        true
      end

      def destroy_domain(domain)
        call(
          :delete,
          { 'Action' => 'DeleteDomain', 'DomainName' => domain.to_s }
        )
        true
      end
      
      
      # Takes a zipped Array or Hash of criteria.
      # Returns a string suitable for a SimpleDB Select
      def self.generate_select(*args)
        fields, domain, args = *args
        q = args.is_a?(Hash) ? args : Hash[*args.flatten]
        query = []
        q.each do |n,v| 
          query << "#{Rudy::AWS.escape n}='#{Rudy::AWS.escape v}'"
        end
        "select * from #{domain} where " << query.join(' and ')
      end

      
      # Takes a zipped Array or Hash of criteria.
      # Returns a string suitable for a SimpleDB Query
      def self.generate_query(*args)
        q = args.first.is_a?(Hash)? args.first : Hash[*args.flatten]
        query = []
        q.each do |n,v| 
          query << "['#{Rudy::AWS.escape n}'='#{Rudy::AWS.escape v}']"
        end
        query.join(" intersection ")
      end


      def select(select, token = nil)
        params = {
          'Action' => 'Select',
          'SelectExpression' => select,
        }
        params['NextToken'] =
          token unless token.nil? || token.empty?

        doc = call(:get, params)
        results = []
        REXML::XPath.each(doc, "//Item") do |item|
          name = REXML::XPath.first(item, './Name/text()').to_s

          attributes = {'Name' => name}
          REXML::XPath.each(item, "./Attribute") do |attr|
            key = REXML::XPath.first(attr, './Name/text()').to_s
            value = REXML::XPath.first(attr, './Value/text()').to_s
            ( attributes[key] ||= [] ) << value
          end
          results << attributes
        end
        #return results, REXML::XPath.first(doc, '//NextToken/text()').to_s
        
        hash_results = {}
        results.each do |item|
          hash_results[item.delete('Name')] = item
        end
        
        hash_results.empty? ? nil : hash_results
      end
      
      # <QueryResult><ItemName>in-c2ffrw</ItemName><ItemName>in-72yagt</ItemName><ItemName>in-52j8gj</ItemName>
      def query(domain, query, max = nil, token = nil)
        params = {
          'Action' => 'Query',
          'QueryExpression' => query,
          'DomainName' => domain.to_s
        }
        params['NextToken'] =
          token unless token.nil? || token.empty?
        params['MaxNumberOfItems'] =
          max.to_s unless max.nil? || max.to_i == 0


        doc = call(:get, params)
        results = []
        REXML::XPath.each(doc, '//ItemName/text()') do |item|
          results << item.to_s
        end
        
        #return results, REXML::XPath.first(doc, '//NextToken/text()').to_s
        results.empty? ? nil : results
        
      end



      # <QueryWithAttributesResult><Item><Name>in-c2ffrw</Name><Attribute><Name>code</Name><Value>in-c2ffrw</Value></Attribute><Attribute><Name>date_created</Name><Value>2008-10-31</Value></Attribute></Item><Item>
      def query_with_attributes(domain, query, max = nil, token = nil)
        params = {
          'Action' => 'QueryWithAttributes',
          'QueryExpression' => query,
          'DomainName' => domain.to_s
        }
        params['NextToken'] =
          token unless token.nil? || token.empty?
        params['MaxNumberOfItems'] =
          max.to_s unless max.nil? || max.to_i == 0

        doc = call(:get, params)
        results = []
        REXML::XPath.each(doc, "//Item") do |item|
          name = REXML::XPath.first(item, './Name/text()').to_s

          attributes = {'Name' => name}
          REXML::XPath.each(item, "./Attribute") do |attr|
            key = REXML::XPath.first(attr, './Name/text()').to_s
            value = REXML::XPath.first(attr, './Value/text()').to_s
            ( attributes[key] ||= [] ) << value
          end
          results << attributes
        end
        #return results, REXML::XPath.first(doc, '//NextToken/text()').to_s
        
        hash_results = {}
        results.each do |item|
          hash_results[item.delete('Name')] = item
        end
        
        hash_results
      end



      def put_attributes(domain, item, attributes, replace = true)
        replace = true if replace == :replace
        params = {
          'Action' => 'PutAttributes',
          'DomainName' => domain.to_s,
          'ItemName' => item.to_s
        }
        count = 0
        
        attributes.each do | key, values |
          ([]<<values).flatten.each do |value|
            params["Attribute.#{count}.Name"] = key.to_s
            params["Attribute.#{count}.Value"] = value.to_s
            params["Attribute.#{count}.Replace"] = replace
            count += 1
          end
        end
        
        call(:put, params)
        
        true
      end
      alias :put :put_attributes
      
      def get_attributes(domain, item)
        doc = call(
          :get,
          {
            'Action' => 'GetAttributes',
            'DomainName' => domain.to_s,
            'ItemName' => item.to_s
          }
        )
        attributes = {}
        REXML::XPath.each(doc, "//Attribute") do |attr|
          key = REXML::XPath.first(attr, './Name/text()').to_s
          value = REXML::XPath.first(attr, './Value/text()').to_s
          ( attributes[key] ||= [] ) << value
        end
        attributes = nil if attributes.empty?
        attributes
      end
      alias :get :get_attributes
      
      
      def delete_attributes(domain, item)
        call(
          :delete,
          {
            'Action' => 'DeleteAttributes',
            'DomainName' => domain.to_s,
            'ItemName' => item.to_s
          }
        )
        true
      end
      alias :destroy :delete_attributes
      


    protected

      def call(method, params)
        params.merge!( {
            'Version' => '2007-11-07',
            'SignatureVersion' => '1',
            'AWSAccessKeyId' => @access_key_id,
            'Timestamp' => Time.now.gmtime.iso8601
          }
        )
        data = ''
        query = []
        
        params.keys.sort_by { |k| k.upcase }.each do |key|
          data << "#{key}#{params[key].to_s}"
          query << "#{key}=#{CGI::escape(params[key].to_s)}"
        end
        
        digest = OpenSSL::Digest::Digest.new('sha1')
        hmac = OpenSSL::HMAC.digest(digest, @secret_access_key, data)
        signature = Base64.encode64(hmac).strip
        query << "Signature=#{CGI::escape(signature)}"
        query = query.join('&')
        url = "#{@base_url}?#{query}"
        uri = URI.parse(url)
        @debug.puts("#{url}") if @debug
        
        response =
          Net::HTTP.new(uri.host, uri.port).send_request(method, uri.request_uri)
        @debug.puts("#{response.code}\n#{response.body}") if @debug
        raise(ConnectionError.new(response)) unless (200..400).include?(
          response.code.to_i
        )
        
        doc = REXML::Document.new(response.body)
        error = doc.get_elements('*/Errors/Error')[0]
        raise(
          Module.class_eval(
            "AwsSdb::#{error.get_elements('Code')[0].text}Error"
          ).new(
            error.get_elements('Message')[0].text,
            doc.get_elements('*/RequestID')[0].text
          )
        ) unless error.nil?
        
        doc
      end
    end

  end
end


