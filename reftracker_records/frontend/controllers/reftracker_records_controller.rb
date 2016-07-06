
class ReftrackerRecordsController < ApplicationController

  set_access_control "update_accession_record" => [:search, :index, :import, :cancel] 

  def index
    # check for required reftracker configuration
    begin
      ReftrackerSettings.check_ref_settings
    rescue ReftrackerConfigurationException => e
       flash[:error] = e.to_s
    end

    render "reftracker_records/index"
  end

  def search
    
    myqno = params["reftracker_records"]["qno"]     
    
    begin       
      # get the reftracker record using reftracker API 
      @reftracker_record = ReftrackerRecord.new.get_refrecords(myqno)

      # get the mappings required by show template
      @ref_as_map = ReftrackerSettings.mappings
      
    rescue Exception, ReftrackerConfigurationException, ReftrackerAPIException => e
       flash[:error] = e.to_s
       render "reftracker_records/index" and return
    end    

    render "reftracker_records/show"     
  end

  def cancel
    flash[:info] = I18n.t('plugins.reftracker_records.messages.cancel_import')
    render "reftracker_records/index"
  end

  def import

    ref_record = params["ref_record"]["data"]      

    begin      
      response = ReftrackerRecord.new.create_accession("#{ref_record}")    
      redirect_to :controller => :jobs, :action => :show, :id => response['id'] 
    rescue
      flash[:error] = $!.to_s
       render "reftracker_records/index"   
    end
    
  end


end
