#Releases

* 1.0.0::  Released to production
* 1.2.0::  Changed <provider_checksum> node to regular <checksum> node.  Must be run in combination with assembly 1.2.0.
* 1.2.2::  Significant refactoring of cleanup scripts and movement of methods to a new Util class.  Update integration tests.
* 1.3.0::  Add the ability to re-accession
* 1.3.1::  Bug fixes related to re-accessioning
* 1.3.2::  Bug fixes related to smpl content metadata processing
* 1.3.3::  Add the ability to leave the progress log filename as nil in the config file, and it will be created automatically.
* 1.3.4::  Add contentMetadata and resourceTypes of 'image' during pre-assembly if you specify :simple_image as project type.
* 1.4.6::  Add functionality to discovery_report to provide information on whether * objects are registered and if they have APOs
* 1.4.7::  Allow "book_as_image" as new project content type.
* 1.4.8::  Fix workflow_status report so it doesn't crash if a workflow is not found
* 1.4.9::  Bug fix in cleanup method
* 1.5.0::  Add the ability to accession or re-accession only specific items via * "except" or "only" parameters
* 1.5.1::  Updates to discovery report to only show objects that will be processed
* 1.5.2::  Add some utility methods to quickly update datastreams for a list of DOR * objects
* 1.5.3::  Add more options to the discovery_report to make it useful when running * manifest style projects
* 1.5.4::  bug fixes to discovery report
* 1.5.5::  Add some more reporting info to the discovery_report (to tell you how * many problems were found when running)
* 1.5.6::  Added additional check to discovery report -- check for any files that * are present in the bundle directory but not referenced in the manifest
* 1.5.7::  Add the ability to check the uniqueness of source IDs to the discovery * report
* 1.5.8::  bug fixes, update to fix tests
* 1.5.9::  update generate_collection_report to add more columns
* 1.6.0::  rename generate_collection_report to project_tag_report and add a new * report that uses the progress YAML file to only report on successfully * accessioned druids
* 1.6.1::  allow users to specify a manifest file for descriptive metadata purposes * even if should_register=false; allow users to bypass image validation
* 1.7.0::  allow for 'joined' method of content metadata generation; allow user to * specify publish/preserve/shelve attributes by mime-type
* 1.7.1::  add further validation checks to ensure only compatible values are set * in YAML before proceeding, some refactoring to keep bundle class smaller, remove * 'use_druid_minter' parameter and set it to a new style of getting druids, show * warnings if you set development only parameters
* 1.7.2::  set completion_report to check actual workflow states in DOR instead of * relying on SOLR, which can be out of date
* 1.7.3::  small bug fix when checking writable status of directories and files; * try and find druids from barcodes when running discovery report
* 1.7.4::  more validation fixes, to indicate that container barcode projects must * have the APO DRUID set
* 1.7.5::  add another check to discovery_report which confirms readable file * permissions on object files
* 1.7.6::  bug fix in discovery_report for barcode projects
* 1.7.7::  move the Utils class into it's own gem so it can be used elsewhere ... * methods that were PreAssembly::Utils are now Assembly::Utils; refactoring to * account for new DruidTools gem usage
* 1.7.8::  bug fixes; update how configuration is done to make it part of * Assembly-utils gem
* 1.7.9::  add time stamps to progress display on screen (or into nohup.out file)
* 1.8.0::  allow the web service call to retry 5 times, sleeping between each call * in order to avoid pre-assembly crashing if the dor web service is temporarily * unavailable
* 1.8.1::  refactor: adjust object_file class to subclass from Assembly::ObjectFile * so we don't need to redeclare convenience methods
* 1.9.0::  use the content metadata generation methods in the updated * Assembly::ObjectFile gem, which expands the possible types of metadata that can * be generated, update templates and documentation
* 1.9.1::  use the new DruidTools gem to generate staged content in the druid tree * format: /oo/000/oo/0001/oo000oo0001/content
* 1.9.2::  update how set relationships are stored in an object -- add both an * isMemberOf and an isMemberOfRelationship
* 1.9.3::  small updates to force new usage of assembly-objectfile gem for latest * contentmetadata generation; additional output at end of preassembly
* 1.9.4::  update discovery_report to include checks for APO existence and * existence of assemblyWF workflow definition
* 1.9.5::  more additions to discovery_report to provide total size and count by * mimetype of discovered files; eliminate need to directly compute md5; this is now * done via the assembly-objectfile gem
* 1.9.6::  add a new configuration parameter that determines if items are staged * using the new style of druid trees or the old style of druid trees in the dor * workspace
* 1.9.7::  provide the option to have no contentMetadata.xml file generated during * pre-assembly.  Useful if you have a current custom created one ready to stage.
* 1.9.8::  update web service call to remove "v1" from URL
* 1.9.9::  allow the content metadata creation style to be discovered from already * registered objects by inspecting the 'Process : Content Type' tag.  The default * is used if not found or mapping incomplete.
* 1.10.0:: added support for the dir_validator gem
* 1.10.1:: updated discovery report to fetch druids; add files needed for mjf
* 1.10.2:: update discovery report to optionally show all staged files; add new * parameter to stageable discovery to optionally stage files only
* 1.10.3:: show detailed exception messages if initiate_accessioning_workflow step * fails after several attempts (useful for debugging)
* 1.10.4:: update discovery report
* 1.10.5:: update README to indicate new convenience methods available in * assembly-utils, update required version of assembly-utils
* 1.10.6:: Update service_root configuration to allow different service URLs (e.g. * with or without v1) for test and production
* 1.10.7:: Allow the dor register call to retry 5 (configurable) times, sleeping * between each call in order to avoid pre-assembly crashing if the dor web service * is temporarily unavailable
* 1.10.8:: Add a new parameter to allow pre-assembly to be throttled (add a sleep * time between objects)
* 1.10.9:: Catch errors on register_object_in_set method call, and allow for * retries before raising an exception
* 1.10.10:: Add spaces in filenames checks to discovery report
* 1.10.11:: Catch errors on get_pid_from_suri method call, and allow for retries * before raising an exception
* 1.10.12:: Delete assemblyWF and accessionWF workflows from objects when * re-accessioning using updated assembly-utils gem
* 1.11.1::  Bump up to latest versions of assembly gems; fix bug in publish * attributing adding during content metadata generation
* 1.11.2::  If user had a trailing slash on the bundle_dir parameter, object * discovery might fail.  Remove any trailing slashes during setup.
* 1.11.3::  Make SMPL contentMetadata generation more robust so it doesn't crash if * the checksum is missing from the preContentMetadata file.
* 1.11.4:: Changed the object type and resource type from 'file' to 'media' for * SMPL conntent metadata.
* 2.0.0::  Allow user to stage items via symlink instead of copy -- useful when * source bundle directory contains large files.  New YAML config parameter is * called "staging_style" and can be set to "copy" or "symlink" (default is "copy").
* 2.0.1::  Attempt cleanup if registration step fails -- try to delete object and * purge from solr before trying again
* 2.0.2:: Add some more intelligence to the validate_usage step to better indicate * errors in YAML configuration; default to new druid tree
* 2.0.3:: Verify that pid starts with druid: when initializing the assembly workflow
* 2.0.4:: Restructure project specific folder to be more generalizable.  Add new * "revs" project specific file that does LC term lookups when generating MODs.
* 2.0.5:: Add new "revs" project specific files with country and state parsing for * location nodes on MODs.
* 2.0.6:: Add some new "revs" project specific methods to check format field
* 2.1.0:: Add a basic remediation framework for mass remediating objects.
* 2.1.1 - 2.1.3:: More updates to remediation framework; revs metadata and image * updating specific code
* 2.1.4:: Allow DOR items to be registered even when a label is not provided in the * manifest, by using a default label instead
* 2.1.5:: If registration fails, try to delete object by source ID as well as by * druid
* 2.1.6:: Update remediation to allow you to skip workflow checks for in * accessioning and versioning required when testing in development and production.
* 2.1.7:: Update remediation script to allow you to pass in a pre-assembly log file * as well as a CSV with druids
* 2.1.8:: Show total number of objects and remaining in remediation output
* 2.2.0:: Allow the user to specify multiple sets/collection objects that should be * associated with an item when registering
* 2.2.1:: Adjust how validate_files works to also check for color profile since * that check is no longer provided with the existing method
* 2.2.2:: Change default mapping for flipbook registered object to simple_book * content metadata; don't override yaml content metedata type with registered * object content tag unless user explicitly indicates this should be done
* 2.2.3:: Move SMPL preContentMetadata generation methods into a class and allow it * to be run automatically whenever SMPL accessioning occurs
* 2.2.4:: Make SMPL content metadata generation per object so that you do not need * to run an extra step ahead of pre-assembly
* 2.2.5:: Make SMPL searching of checksums in MD5 file case insensitive for the * role folder
* 2.2.6:: Add some additional info to the discovery report for SMPL manifest * projects
* 2.2.7-2.2.8:: Enable automated combination of all techmd.xml files for SMPL * projects into a single technical metadata datastream; cleanup old methods
* 2.3.1:: Remove revs specific shared methods from revs project file, include their * functionality from the new revs-utils gem
* 2.3.2:: Small changes to discovery report around checking for APOs and objects; * do not fail if label column is missing from manifest for should_register=false
* 2.3.6:: Use latest version of assembly-image and assembly-objectfile gems
* 2.3.7:: Use latest version of revs-utils.  Allow manifests to have UTF-8 * characters (switch manifest loading from csv-mapper to standard CSV library)
* 2.3.8:: Fixes to manifest loading and access to always use hash style references * for columns (instead of allowing for struct like syntax that came from * csv-mapper). Fix rdf gem to 1.0.9 until activefedora is updated to v6
* 2.3.9:: Send default title to registration service if no label is provided in the * manifest
* 2.4.0:: Added a new MODs generation report so you can test your MODs desc md * template before you actually run accessioning.
* 2.4.1:: Update a revs related mods test.
* 2.4.2:: Remove dependency on lyber-core, update other gems (including * dor-services)
* 2.4.3:: Allow user to specify a tag to be applied to each object when registering
* 2.4.4:: Add some additional scripts to help prep Revs content.  Allow * desc_metadata_templates to be specified with an absolute path as well as a * relative path.
* 2.4.5:: Add in retry logic around validate_files since it still seems to fail * sporadically.  Update to the revs_create_yaml script.  Use new version of * assembly-objectfile which gets mimetype from file extension.
* 2.4.6:: Add garbage collection each X objects pre-assembled; add optional memory * profiling
* 2.4.7:: Do not add descmd xml template to every digital object when processing to * lower memory usage.  Add a new script for easier batch processing.
* 
