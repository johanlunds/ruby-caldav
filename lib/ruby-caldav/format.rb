# frozen_string_literal: true

module CalDAV
  module Format
    class Raw
      def method_missing(_, *args)
        args
      end
    end

    class Debug < Raw
    end

    class Pretty < Raw
      def parse_calendar(s)
        result = ''
        xml = REXML::Document.new(s)

        REXML::XPath.each(xml, '//c:calendar-data/', { 'c' => 'urn:ietf:params:xml:ns:caldav' }) do |c|
          result << c.text
        end
        Icalendar.parse(result)
      end

      def parse_todo(body)
        result = []
        xml = REXML::Document.new(body)
        REXML::XPath.each(xml, '//c:calendar-data/', { 'c' => 'urn:ietf:params:xml:ns:caldav' }) do |c|
          p c.text
          p parse_tasks(c.text)
          result += parse_tasks(c.text)
        end
        result
      end

      def parse_tasks(vcal)
        return_tasks = []
        cals = Icalendar.parse(vcal)
        cals.each do |tcal|
          tcal.todos.each do |ttask| # FIXME
            return_tasks << ttask
          end
        end
        return_tasks
      end

      def parse_events(vcal)
        Icalendar.parse(vcal)
      end

      def parse_single(body)
        # FIXME: parse event/todo/vcard
        parse_events(body)
      end
    end
  end
end
