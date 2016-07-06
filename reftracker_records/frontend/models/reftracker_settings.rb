class ReftrackerAPIException < StandardError; end

class ReftrackerConfigurationException < StandardError; end

module ReftrackerSettings

  class LoadSettings

    def load_mappings
       # Load csv mappings file - /plugins/reftracker_records/frontend/reftracker_aspace_mappings.csv 
       # CSV row order: [ArchivesSpace accession fields], [Reftracker-labels], [Reftracker-internal fields]
      ref_as_map_path = File.expand_path('../reftracker_aspace_mappings.csv',  File.dirname(__FILE__))
      
      as_rl__ri_csv = CSV.read(ref_as_map_path, { encoding: "UTF-8" })   

      unless as_rl__ri_csv.length == 3 || [as_rl__ri_csv[0],as_rl__ri_csv[1],as_rl__ri_csv[2]].all? {|k| k.length == as_rl__ri_csv[0].length}
        raise ReftrackerConfigurationException.new(I18n.t('plugins.reftracker_records.messages.malformed_csv', :csv => "#{ref_as_map_path}")) 
      end

      # strip whitespace from all values 
      [as_rl__ri_csv[0],as_rl__ri_csv[1],as_rl__ri_csv[2]].all? {|k| k.map! { |x| x.strip unless x.nil? } }

      as_rl__ri_csv
    end

    def load_opts
      ref_keys = ["reftracker_base_url", "reftracker_mandatory_fields"]
      opts = Hash[ref_keys.map{ |setting| ["#{setting}", AppConfig[:"#{setting}"].strip]}]

      unless ref_keys.all? {|k| opts.key? k}
        raise ReftrackerConfigurationException.new(I18n.t('plugins.reftracker_records.messages.missing_configuration', :opt => "#{ref_keys}")) 
      end 

      opts          
    end

    def check_settings
      missing = []
      #check config files contain reftracker configuration
      %w(base_url mandatory_fields).each do |setting|
        unless AppConfig.has_key?(:"reftracker_#{setting}")
          missing << I18n.t("plugins.reftracker_records.#{setting}")
        end
      end
      #check csv mapping file is present
      ref_as_map_path = File.expand_path('../reftracker_aspace_mappings.csv',  File.dirname(__FILE__))
      
      unless File.exists?(ref_as_map_path)  
        missing << I18n.t('plugins.reftracker_records.mappings_file')    
      end  
      
      unless missing.empty? 
        raise ReftrackerConfigurationException.new(I18n.t('plugins.reftracker_records.messages.missing_configuration', :params =>missing.join(", ")))
      end 
    end

  end ## end of class LoadSettings

    ## convenience methods

    def self.check_ref_settings
       LoadSettings.new.check_settings
    end

    def self.ref_opts       
      @@opts ||= LoadSettings.new.load_opts            
    end

    def self.mappings                        
      @@as_rl_ri ||= LoadSettings.new.load_mappings
    end

end  ## end of module
