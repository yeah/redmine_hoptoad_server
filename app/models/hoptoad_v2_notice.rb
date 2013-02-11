class HoptoadV2Notice
  attr_reader :redmine_params

  def initialize(data)
    xml = Nokogiri::XML(data)
    @redmine_params = YAML.load(xml.xpath('//api-key').first, :safe => true)

    error = {
      'class' => (xml.xpath('//error/class').first.content rescue nil),
      'message' => (xml.xpath('//error/message').first.content rescue nil),
      'backtrace' => []
    }
    xml.xpath('//error/backtrace/line').each do |line|
      error['backtrace'] << { 'number' => line['number'], 'file' => line['file'], 'method' => line['method'] }
    end

    env = {}
    xml.xpath('//server-environment/*').each{|element| env[element.name] = element.content}

    req = {
      'params' => {},
      'cgi-data' => {}
    }
    xml.xpath('//request/*').each do |element|
      case element.name
      when 'params', 'cgi-data'
        req[element.name] = parse_key_values(element.xpath('var'))
      else
        req[element.name] = element.content
      end
    end

    @notice = {
      'error' => error,
      'server_environment' => env,
      'request' => req
    }
  end

  def [](key)
    @notice[key]
  end

  private

  def parse_key_values(xml)
    {}.tap do |result|
      xml.each do |element|
        result[element['key']] = element.content
      end
    end
  end
end
