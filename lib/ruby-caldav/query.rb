# frozen_string_literal: true

module CalDAV
  class Query
    attr_accessor :child

    # TODO: raise error if to_xml is called before child is assigned
    def to_xml(xml = Builder::XmlMarkup.new(indent: 2))
      xml.instruct!
      xml.tag! 'cal:calendar-query', CalDAV::NAMESPACES do
        xml.tag! 'dav:prop' do
          xml.tag! 'dav:getetag'
          xml.tag! 'cal:calendar-data'
        end
        xml.tag! 'cal:filter' do
          cal = Filter::Component.new('VCALENDAR', self)
          cal.child = child
          cal.build_xml(xml)
        end
      end
    end

    def event(param = nil)
      self.child = Filter::Component.new('VEVENT')
      case param
      when Range
        child.time_range(param)
      when String
        child.uid(param)
      else
        child
      end
    end

    def todo(_param = nil)
      self.child = Filter::Component.new('VTODO')
      child
    end

    def child=(child)
      child.parent = self
      @child = child
    end

    def self.event(param = nil)
      new.event(param)
    end

    def self.todo(_param = nil)
      new.todo
    end
  end
end
