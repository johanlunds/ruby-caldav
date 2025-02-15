# frozen_string_literal: true

module CalDAV
  class Client
    include Icalendar
    attr_accessor :host, :port, :url, :user, :password, :ssl

    attr_writer :format

    def with_retry(times = 3)
      counter = 1
      begin
        yield
      rescue StandardError
        counter += 1
        retry if counter > times
      end
    end

    def format
      @format ||= Format::Debug.new
    end

    def initialize(data)
      unless data[:proxy_uri].nil?
        proxy_uri   = URI(data[:proxy_uri])
        @proxy_host = proxy_uri.host
        @proxy_port = proxy_uri.port.to_i
      end

      uri = URI(data[:uri])
      @host     = uri.host
      @port     = uri.port.to_i
      @url      = uri.path
      @user     = data[:user]
      @password = data[:password]
      @ssl      = uri.scheme == 'https'
      @debug    = data[:debug]

      if data[:authtype].nil?
        @authtype = 'basic'
      else
        @authtype = data[:authtype]
        case @authtype
        when 'digest'

          @digest_auth = Net::HTTP::DigestAuth.new
          @duri = URI.parse data[:uri]
          @duri.user = @user
          @duri.password = @password

        when 'basic'
        # this is fine for us
        else
          raise 'Please use basic or digest'
        end
      end
    end

    def __create_http
      http = if @proxy_uri.nil?
               Net::HTTP.new(@host, @port)
             else
               Net::HTTP.new(@host, @port, @proxy_host, @proxy_port)
             end
      if @ssl
        http.use_ssl = @ssl
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.max_retries = 3
      http.set_debug_output $stderr if @debug
      http
    end

    def find_events(data)
      result = ''
      events = []
      res = nil
      __create_http.start do |http|
        req = Net::HTTP::Report.new(@url, { 'Content-Type' => 'application/xml', 'Depth' => '1' })

        if @authtype != 'digest'
          req.basic_auth @user, @password
        else
          req.add_field 'Authorization', digestauth('REPORT')
        end
        if data[:start].is_a? Integer
          req.body = CalDAV::Request::ReportVEVENT.new(Time.at(data[:start]).utc.strftime('%Y%m%dT%H%M%S'),
                                                       Time.at(data[:end]).utc.strftime('%Y%m%dT%H%M%S')).to_xml
        else
          req.body = CalDAV::Request::ReportVEVENT.new(Time.parse(data[:start]).utc.strftime('%Y%m%dT%H%M%S'),
                                                       Time.parse(data[:end]).utc.strftime('%Y%m%dT%H%M%S')).to_xml
        end
        res = http.request(req)
      end
      errorhandling res
      result = String.new
      # puts res.body
      xml = REXML::Document.new(res.body)
      REXML::XPath.each(xml, '//c:calendar-data/', { 'c' => 'urn:ietf:params:xml:ns:caldav' }) { |c| result << c.text }
      r = Icalendar.parse(result)
      if r.empty?
        []
      else
        r.each do |calendar|
          calendar.events.each do |event|
            events << event
          end
        end
        events
      end
    end

    def find_event(uuid)
      with_retry do
        res = nil
        __create_http.start do |http|
          req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
          if @authtype != 'digest'
            req.basic_auth @user, @password
          else
            req.add_field 'Authorization', digestauth('GET')
          end
          res = http.request(req)
        end
        errorhandling res
      end
      begin
        r = Icalendar.parse(res.body)
      rescue StandardError
        false
      else
        r.first.events.first
      end
    end

    def delete_event(uuid)
      with_retry do
        res = nil
        __create_http.start do |http|
          req = Net::HTTP::Delete.new("#{@url}/#{uuid}.ics")
          if @authtype != 'digest'
            req.basic_auth @user, @password
          else
            req.add_field 'Authorization', digestauth('DELETE')
          end
          res = http.request(req)
        end
        errorhandling res
      end
      # accept any success code
      if res.code.to_i.between?(200, 299)
        true
      else
        false
      end
    end

    def create_event(event)
      c = Calendar.new
      c.events = []
      uuid = UUID.new.generate
      raise DuplicateError if entry_with_uuid_exists?(uuid)

      c.event do
        uid           uuid
        dtstart       DateTime.parse(event[:start])
        dtend         DateTime.parse(event[:end])
        categories    event[:categories] # Array
        contacts      event[:contacts] # Array
        attendees     event[:attendees] # Array
        duration      event[:duration]
        summary       event[:title]
        description   event[:description]
        klass         event[:accessibility] # PUBLIC, PRIVATE, CONFIDENTIAL
        location      event[:location]
        geo_location  event[:geo_location]
        status        event[:status]
        url           event[:url]
        rrule         event[:rrule]
      end
      cstring = c.to_ical
      with_retry do
        res = nil
        __create_http.start do |http|
          req = Net::HTTP::Put.new("#{@url}/#{uuid}.ics")
          req['Content-Type'] = 'text/calendar'
          if @authtype != 'digest'
            req.basic_auth @user, @password
          else
            req.add_field 'Authorization', digestauth('PUT')
          end
          req.body = cstring
          res = http.request(req)
        end
        errorhandling res
      end
      find_event uuid
    end

    def update_event(event)
      # TODO... fix me
      if delete_event event[:uid]
        create_event event
      else
        false
      end
    end

    def add_alarm(tevent, alt_cal = 'Calendar'); end

    def find_todo(uuid)
      res = nil
      __create_http.start do |http|
        req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
        if @authtype != 'digest'
          req.basic_auth @user, @password
        else
          req.add_field 'Authorization', digestauth('GET')
        end
        res = http.request(req)
      end
      errorhandling res
      r = Icalendar.parse(res.body)
      r.first.todos.first
    end

    # FIXME: Lint/DuplicateMethods: Method CalDAV::Client#create_todo is defined at both lib/ruby-caldav/client.rb:226 and lib/ruby-caldav/client.rb:264
    def create_todo(todo)
      c = Calendar.new
      uuid = UUID.new.generate
      raise DuplicateError if entry_with_uuid_exists?(uuid)

      c.todo do
        uid           uuid
        start         DateTime.parse(todo[:start])
        duration      todo[:duration]
        summary       todo[:title]
        description   todo[:description]
        klass         todo[:accessibility] # PUBLIC, PRIVATE, CONFIDENTIAL
        location      todo[:location]
        percent       todo[:percent]
        priority      todo[:priority]
        url           todo[:url]
        geo           todo[:geo_location]
        status        todo[:status]
        rrule         todo[:rrule]
      end
      c.todo.uid = uuid
      cstring = c.to_ical
      res = nil
      __create_http.start do |http|
        req = Net::HTTP::Put.new("#{@url}/#{uuid}.ics")
        req['Content-Type'] = 'text/calendar'
        if @authtype != 'digest'
          req.basic_auth @user, @password
        else
          req.add_field 'Authorization', digestauth('PUT')
        end
        req.body = cstring
        res = http.request(req)
      end
      errorhandling res
      find_todo uuid
    end

    # FIXME: Lint/DuplicateMethods: Method CalDAV::Client#create_todo is defined at both lib/ruby-caldav/client.rb:226 and lib/ruby-caldav/client.rb:264
    def create_todo
      res = nil
      raise DuplicateError if entry_with_uuid_exists?(uuid)

      __create_http.start do |http|
        req = Net::HTTP::Report.new(@url, { 'Content-Type' => 'application/xml' })
        if @authtype != 'digest'
          req.basic_auth @user, @password
        else
          req.add_field 'Authorization', digestauth('REPORT')
        end
        req.body = CalDAV::Request::ReportVTODO.new.to_xml
        res = http.request(req)
      end
      errorhandling res
      format.parse_todo(res.body)
    end

    private

    def digestauth(method)
      h = Net::HTTP.new @duri.host, @duri.port
      if @ssl
        h.use_ssl = @ssl
        h.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      req = Net::HTTP::Get.new @duri.request_uri

      res = h.request req
      # res is a 401 response with a WWW-Authenticate header

      @digest_auth.auth_header @duri, res['www-authenticate'], method
    end

    def entry_with_uuid_exists?(uuid)
      res = nil

      __create_http.start do |http|
        req = Net::HTTP::Get.new("#{@url}/#{uuid}.ics")
        if @authtype != 'digest'
          req.basic_auth @user, @password
        else
          req.add_field 'Authorization', digestauth('GET')
        end

        res = http.request(req)
      end
      begin
        errorhandling res
        Icalendar.parse(res.body)
      rescue StandardError
        false
      else
        true
      end
    end

    def errorhandling(response)
      raise NotExistError if response.code.to_i == 404
      raise AuthenticationError if response.code.to_i == 401
      raise NotExistError if response.code.to_i == 410
      raise APIError if response.code.to_i >= 500
    end
  end

  class CalDAVError < StandardError
  end

  class AuthenticationError < CalDAVError; end
  class DuplicateError      < CalDAVError; end
  class APIError            < CalDAVError; end
  class NotExistError       < CalDAVError; end
end
