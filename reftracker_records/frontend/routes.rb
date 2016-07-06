ArchivesSpace::Application.routes.draw do

  match('plugins/reftracker_records'        => 'reftracker_records#index',  :via => [:get])
  match('plugins/reftracker_records/search' => 'reftracker_records#search', :via => [:post])
  match('plugins/reftracker_records/import' => 'reftracker_records#import', :via => [:post])
  match('plugins/reftracker_records/cancel' => 'reftracker_records#cancel', :via => [:get])

end
