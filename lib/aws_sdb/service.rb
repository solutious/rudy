require 'logger'
require 'time'
require 'cgi'
require 'uri'
require 'net/http'
require 'base64'
require 'openssl'
require 'rexml/document'
require 'rexml/xpath'

module AwsSdb

  class Service
    def initialize(options={})
      @access_key_id = options[:access_key_id] || ENV['AMAZON_ACCESS_KEY_ID']
      @secret_access_key = options[:secret_access_key] || ENV['AMAZON_SECRET_ACCESS_KEY']
      @base_url = options[:url] || 'http://sdb.amazonaws.com'
      @logger = options[:logger] || Logger.new("aws_sdb.log")
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
      return results, REXML::XPath.first(doc, '//NextToken/text()').to_s
    end

    def create_domain(domain)
      call(:post, { 'Action' => 'CreateDomain', 'DomainName'=> domain.to_s })
      nil
    end

    def delete_domain(domain)
      call(
        :delete,
        { 'Action' => 'DeleteDomain', 'DomainName' => domain.to_s }
      )
      nil
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
      return results, REXML::XPath.first(doc, '//NextToken/text()').to_s
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
      return results, REXML::XPath.first(doc, '//NextToken/text()').to_s

    end

    def put_attributes(domain, item, attributes, replace = true)
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
      nil
    end

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
      attributes
    end

    def delete_attributes(domain, item)
      call(
        :delete,
        {
          'Action' => 'DeleteAttributes',
          'DomainName' => domain.to_s,
          'ItemName' => item.to_s
        }
      )
      nil
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
      return results, REXML::XPath.first(doc, '//NextToken/text()').to_s
    end

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
      @logger.debug("#{url}") if @logger
      response =
        Net::HTTP.new(uri.host, uri.port).send_request(method, uri.request_uri)
      @logger.debug("#{response.code}\n#{response.body}") if @logger
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
