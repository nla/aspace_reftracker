Import Reftracker Records
==========================

# Description

"Import Reftracker Records" plugin enables an ArchivesSpace user to import a Reftracker record into ArchivesSpace as Accession record.

The plugin is available to users from the "Plug-ins" drop down menu on the top bar, above the repository widget on the ArchivesSpace home page.

The user must select an appropriate repository (e.g. Manuscripts or Pictures) before initiating the import.

The plugin uses a custom csv file containing archivesspace-reftracker field mappings to map the data between two systems. 
It programmatically creates an ArchivesSpace background job of type "Import data" and uses "accession.csv" template internally to create an accession record.

It complains if user attempts to:
	Enter more than one unique Reftracker question number in the input field.
	Import same question more than once in one repository (ArchivesSpace checks for unique identifier).
	Import a question which is not closed in Reftracker or was marked as "Knowledge Base".
	Import a question where mandatory Reftracker field values are missing.

All messages are in the en.yml file.
Plugin normalises the boolean fields if data is presented and maintains the formatting (new line characters) in imported text fields.

# Getting Started

Download the latest release from the Releases tab in Github:
https://github.com/...

Unzip it to the plugins directory:

    $ cd /path/to/archivesspace/plugins
    $ unzip /path/to/your/downloaded/aspace-reftracker.zip
    $ mv aspace-reftracker/reftracker_records .
    $ rmdir aspace-reftracker

Enable the plugin by editing the file in 'config/config.rb':

    AppConfig[:plugins] = ['some_plugin', 'reftracker_records']

(Make sure you uncomment this line (i.e., remove the leading '#' if present))
See also: https://github.com/archivesspace/archivesspace/blob/master/plugins/README.md

In 'config/config.rb' set the base url of your Reftracker API and add a comma seperated list of ArchivesSpace fields mapped to the Reftracker mandatory fields: 

    AppConfig[:reftracker_base_url] = { Your Reftracker API url }
    
    AppConfig[:reftracker_mandatory_fields] = { Your list of ArchivesSpace equivalents for Reftracker mandatory fields to be imported } 
    e.g. "accession_number_1, accession_accession_date, agent_role, agent_type, agent_contact_name, agent_name_name_order, agent_name_source, subject_source, subject_term, subject_term_type"

Create a custom csv mappings file "reftracker_aspace_mappings.csv" containing:

	Row 1: ArchivesSpace fields: headers from "accession.csv", maintaining the order
	Row 2: Mapped Reftracker labels 
	Row 3: Mapped Reftracker internal fields

Place "reftracker_aspace_mappings.csv" file under the plugin's frontend directory:
 	plugins/reftracker_records/frontend/reftracker_aspace_mappings.csv 

# How to use it

Start ArchivesSpace. Select the repository. 

From the "Plug-ins" drop down menu on the top bar select "Import Reftracker Records". Enter a unique Reftracker question number in the input field and hit "Search". 

If record exists in reftracker, a preview of mapped data is presented. 

Click "Import" to create the accession in ArchivesSpace or "Cancel" to start again after making changes to the reftracker record in the Reftracker. 
