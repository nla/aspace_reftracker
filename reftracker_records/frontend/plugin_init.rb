require 'rubygems'
require 'fileutils'
require 'logger'  

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'gems', 'htmlentities-4.3.4', 'lib')))

my_routes = [File.join(File.dirname(__FILE__), "routes.rb")]
ArchivesSpace::Application.config.paths['config/routes'].concat(my_routes)

FileUtils.mkdir_p(File.join(ASUtils.find_base_directory, 'logs'))

class ReftrackerLog

  log_path = File.join(ASUtils.find_base_directory, 'logs', 'reftracker.out')
  # Keep data for today and the past 1 (replace 1 by 20 for past 20 days) days. 
  @@logger ||= Logger.new(log_path, 'daily', 1)
  @@logger.level = Logger::DEBUG
  @@logger.formatter = proc do |severity, datetime, progname, msg|
     "#{severity} [#{datetime.strftime('%Y-%m-%d %H:%M:%S.%L')}]: #{msg}\n"
    end

    def self.log(text)
    @@logger.debug(text)
  end

end

ReftrackerLog.log ("Reftracker Plugin Initialised.")


