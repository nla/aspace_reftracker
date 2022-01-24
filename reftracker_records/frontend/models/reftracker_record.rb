require 'json'
require 'csv'
require 'date'
require 'net/http'
require 'asutils'
require 'jsonmodel'
require 'securerandom'
require 'htmlentities'

class ReftrackerRecord 

  def get_refrecords(myqno)
    
    # validate question number
    qno = check_qno_valid(myqno)

    # get reftracker base_url    
    base_url = ReftrackerSettings.ref_opts["reftracker_base_url"]

    #get reftracker_internal fields from csv to create columns_list for Post 
    columns_list = ReftrackerSettings.mappings[2].compact.join('|')
     
    #set search params 
    search_params = 
      {
        :questionno => qno + '|' + qno,
        :db => '5',
        :columnList => columns_list
      }
  
      params = 
      {
        :parameters => search_params.to_json
      }  
      
      payload = nil    
    
    # Query the Reftracker API - search for question number
    begin
      uri = URI(base_url)      
      
      req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
      req.set_form_data(params)

      # log the request to Reftracker API
      ReftrackerLog.log "Reftracker Request: #{req.body}"
      
      response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|     
        http.request(req)    
      end

      # log the response from Reftracker API
      ReftrackerLog.log "Reftracker Response: #{response.body}" 
      Rails.logger.debug(response)

    rescue Exception => e
      raise ReftrackerAPIException.new(I18n.t('plugins.reftracker_records.messages.server_error', :error => e.backtrace.join("\n")))
    end
    
    response_body = response.body.force_encoding('UTF-8')   
    
    if response.code != '200'
        raise ReftrackerAPIException.new(I18n.t('plugins.reftracker_records.messages.server_error', :error => "#{response.body}"))       
      end

    # check callback for reftracker record
    if response_body[/\[(.*)\]/,1].blank? 
        raise ReftrackerAPIException.new(I18n.t('plugins.reftracker_records.messages.qno_not_found', :qno => "#{qno}"))
      end
     
     # extract the payload of call back function
    payload = JSON.parse(response_body[/\[(.*)\]/,1]) 

    # check whether the returned record is for the requested qno
    if (payload["question_no"] != qno)          
        payload = nil
        raise ReftrackerAPIException.new(I18n.t('plugins.reftracker_records.messages.qno_not_found', :qno => "#{qno}")) 
      end

    # check for mandatory reftracker fields
    missing = check_for_mandatory_fields(payload)
    unless missing.empty? 
        raise ReftrackerAPIException.new(I18n.t('plugins.reftracker_records.messages.ref_mandatory_fields', :fields => missing.join(", "), :qno => "#{qno}"))
    end 

    payload
  end


  def create_accession(record)

    if record.blank?
      raise ReftrackerAPIException.new(I18n.t('plugins.reftracker_records.messages.missing_data'))  
    end

    # posted record is a string - convert to hash
    ref_record = JSON.parse record.gsub('=>', ':')
    
    # validate data and create accession.csv file 
    tempfile = create_upload_file(ref_record)
     
    # Create ArchivesSpace job, upload files and post to backend
    job = Job.new("import_job",
                    {
                      "import_type" => "accession_csv",
                      "jsonmodel_type" => "import_job"
                    },
                    {"reftracker_import_#{SecureRandom.uuid}" => tempfile })
    
    begin 
      upload_files = job.instance_variable_get(:@files).each_with_index.map {|file, i|
        (original_filename, stream) = file
        io = File.open(stream)
        stringIO = StringIO.new(io.read)
        ["files[#{i}]", UploadIO.new(stringIO, "text/plain", original_filename)]
      }
    rescue Exception => e
      raise ReftrackerAPIException.new(e)
    end
 
    payload = Hash[upload_files].merge('job' => job.instance_variable_get(:@job).to_json)

    resp = JSONModel::HTTP.post_form("#{JSONModel(:job).uri_for(nil)}_with_files",
                                         payload,
                                         :multipart_form_data)

    response = ASUtils.json_parse(resp.body)    
    Rails.logger.debug(response)  

    response
  end


  private

    def check_qno_valid(myqno) 
    
    # check qno was provided (already mandatory in interface)
    if myqno.empty?        
       raise Exception.new(I18n.t('plugins.reftracker_records.messages.qno_not_provided'))
    end
    
    # check provided qno is unique single
    qno_id = myqno.split(/\s+/).uniq
    if (qno_id.count > 1)
      raise Exception.new(I18n.t('plugins.reftracker_records.messages.more_than_one_qno', :qnos => qno_id.join(", "))) 
    end
    
    qno = "#{qno_id.first}"
  end

  def check_for_mandatory_fields(record)
    
    missing = []
    # get csv mappings
    mappings = ReftrackerSettings.mappings

    # get reftracker configuration
    opts = ReftrackerSettings.ref_opts
    mandatory_fields = opts["reftracker_mandatory_fields"].split(/\s*,\s*/).map(&:strip)  ## creates array

    mappings[0].each.with_index do |as, index| 
      if mandatory_fields.include? as 
        key = mappings[2][index]
        unless record.has_key?("#{key}") && !record["#{key}"].nil?
          missing << mappings[1][index]
        end
      end 
    end

    missing  
  end

  def create_upload_file(ref_record)

    # get csv mappings to create hash from aspace and reftracker internal fields
    mappings = ReftrackerSettings.mappings     
    ref_aspace_map = Hash[mappings[0].zip(mappings[2])]  
    
    # Create a new hash. For each key in ref_aspace_map, find its value in params hash and create an array of key value pairs. 
    acc_record = Hash[ref_aspace_map.map{|key, value| [key, ref_record[value]]}]
    
    # Customisation - set AS mandatory field agent primary name with client name from reftracker if organisation name (client name2) is not provided 
    acc_record["agent_name_primary_name"] = ref_record["client_name"] if acc_record["agent_name_primary_name"].blank? 

    # Customisation - set AS field 'accession_general_note' with default fixed value
    acc_record["accession_general_note"] = "PO#:\r\nPREVIOUS LOCATIONS:" if acc_record["accession_general_note"].blank? 

    # Check and set default Archives Space boolean field values if they exist in the reftracker record
    as_boolean_fields = ["user_defined_boolean_1","user_defined_boolean_2","user_defined_boolean_3","accession_publish","accession_restrictions_apply","accession_use_restrictions", "accession_rights_determined",
    "accession_acknowledgement_sent","accession_agreement_received","accession_agreement_sent","accession_cataloged","accession_processed"]

    as_boolean_fields.all? { |x| acc_record[x].upcase.match(/\A(1|T|Y|YES|TRUE)\Z/) ? acc_record[x] = 1 : acc_record[x] = 0 unless (!acc_record.has_key? x or acc_record[x].nil?) }

    # Remove telephone entries from accession hash if empty
    acc_record.except!('agent_contact_telephone','agent_contact_telephone_ext') if acc_record['agent_contact_telephone'].blank?

    # Decode HTML entities; escape \r\n newline characters for csv to handle values correctly
    acc_record_escpd = Hash[acc_record.map { |k,v| [k, (v =~ /[\r\n]/) ? "\"#{HTMLEntities.new.decode(v)}\"" : v.blank? ? v : HTMLEntities.new.decode(v)] }]

    csv_string = CSV.generate do |csv|
       csv << acc_record_escpd.keys
       csv << acc_record_escpd.values
    end

    tempfile = ASUtils.tempfile('reftracker_import')
    tempfile.write(csv_string)
    tempfile.flush
    tempfile.rewind

    tempfile
  end  

end ##end of class


