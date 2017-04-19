require 'net/http'
require 'json'

module Meetupinator
  # This class is responsible for communicating with the meetup.com API
  # and returning the json responses only.
  class MeetupAPI
    attr_reader :api_key

    def initialize(api_key = nil)
      @base_uri = 'api.meetup.com'
      @groups_endpoint = '/2/groups'
      @events_endpoint = '/2/events'
      @api_key = pick_which_api_key(api_key)
    end

    def get_meetup_id(group_url_name)
      query_string = 'key=' + @api_key + '&group_urlname=' + group_url_name
      uri = URI::HTTP.build(host: @base_uri, path: @groups_endpoint,
                            query: query_string)
      extract_meetup_id get_meetup_response(uri)
    end

    def get_upcoming_events(group_ids, weeks)
      query_string = 'sign=true&photo-host=public&status=upcoming&key=' +
                     @api_key + '&group_id=' + group_ids.join(',')

      query_string << "&time=,#{weeks}w" if weeks

      uri = URI::HTTP.build(host: @base_uri, path: @events_endpoint,
                            query: query_string)
      response = get_meetup_response uri
      get_results response
    end

    private

    def get_meetup_response(uri)
      retries = 3
      begin
        retries -= 1
        response = Net::HTTP.get_response uri
        fail_if_not_ok(uri, response)
        JSON.parse response.body
      rescue JSON::ParserError
        retry unless retries < 0
        msg = "Unable to parse the response for call to #{uri}."
        msg << get_response_body_msg(response)
        fail msg
      rescue
        retry unless retries < 0
        raise
      end
    end

    def fail_if_not_ok(uri, response)
      return if response.kind_of? Net::HTTPSuccess
      msg = "Call to #{uri} failed: #{response.code} - #{response.message}."
      msg << get_response_body_msg(response)
      fail msg
    end

    def get_response_body_msg(response)
      if response.class.body_permitted? then "\nResponse Body:\n#{response.body}" else "" end
    end

    def extract_meetup_id(response)
      get_results(response)[0]['id']
    end

    def get_results(response)
      response['results']
    end

    def pick_which_api_key(api_key)
      key = api_key if key_valid?(api_key)
      key = ENV['MEETUP_API_KEY'] if key_found_in_env? && key_invalid?(key)
      key_invalid?(key) ? fail('no MEETUP_API_KEY provided') : key
    end

    def key_valid?(api_key)
      !(api_key.nil? || api_key.empty?)
    end

    def key_invalid?(api_key)
      !key_valid?(api_key)
    end

    def key_not_found_in_env?
      !key_found_in_env?
    end

    def key_found_in_env?
      (!ENV['MEETUP_API_KEY'].nil? && !ENV['MEETUP_API_KEY'].empty?)
    end
  end
end
