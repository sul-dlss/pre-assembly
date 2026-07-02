# Pre-Assembly

[![CircleCI](https://circleci.com/gh/sul-dlss/pre-assembly/tree/main.svg?style=svg)](https://circleci.com/gh/sul-dlss/pre-assembly/tree/main)
[![codecov](https://codecov.io/github/sul-dlss/pre-assembly/graph/badge.svg?token=8DsPm8gAGZ)](https://codecov.io/github/sul-dlss/pre-assembly)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpre-assembly.svg)](https://badge.fury.io/gh/sul-dlss%2Fpre-assembly)

This is a Ruby implementation of services needed to prepare objects to be
assembled and then accessioned into the SUL digital library.

## Basics

`Pre-Assembly` is a Rails web-app at https://sul-preassembly-prod.stanford.edu/. There is a link in the upper right to "Usage Instructions" which goes to the github wiki pages: https://consul.stanford.edu/spaces/SDR/pages/1812791944/Preassembly.

To understand how to create manifests, accession objects, and stage content, see the Usage Instructions. 

## Deployment

Deploy the Web app version in the usual capistrano manner:

```bash
cap stage deploy
cap prod deploy
```

See the `Capfile` for more info.

## Setting up code for local development

Clone project:

```bash
git clone git@github.com:sul-dlss/pre-assembly.git
cd pre-assembly
```

## Prerequisites

### Get needed gems

```bash
bundle install
```

## Development/Test

The pre-assembly app requires redis and postgres for local development and testing. In order to run the tests or run the
webapp locally, you will need to have start these dependencies via `docker compose`:

```bash
docker compose up -d
```

### Prepare for testing

```bash
# Makes sure the DB is ready, assets are built, and javascript dependencies are installed
bin/rake db:prepare test:prepare
```

### Install exiftool

You need `exiftool` on your system in order to successfully run all of the tests.

On RHEL, download latest version from: http://www.sno.phy.queensu.ca/~phil/exiftool

```bash
tar -xf Image-ExifTool-#.##.tar.gz
cd Image-ExifTool-#.##
perl Makefile.PL
make test
sudo make install
```

On MacOSX, use `homebrew` to install:

```bash
brew install exiftool
```

### Running tests

```bash
docker compose up
bundle exec rspec
```

## Local development

Just the usual:

```bash
bin/dev
```

When running the application in development mode, it will use a default sunet_id (`'tmctesterson'`) for
its sessions. To override that behavior and specify an alternate user, you can manually specify the `REMOTE_USER`
environment variable at startup, like so:

```bash
REMOTE_USER=ima_user bin/dev
rdbg -A # run in separate terminal window if you want a seperate debugger window
```

Because the application looks for user info in an environment variable, and because local dev environments don't have
an Apache module setting that environment variable per request based on headers from Webauth/Shibboleth, dev just always
sets a single value in that env var at start time. So laptop dev instances basically only allow one fake login at a time.

### Globus client gem

The Globus client gem needs to be configured for it work in stage/qa during development.  You will need the client_id/secrets/config from vault for the pre-assembly application, and then add them to your `config/settings.local.yml`, matching the Globus config setup shown in `config/settings.yml`.

## Post Accessioning Reports

Use [Argo](https://argo.stanford.edu/).

## Preparing maps content

Used to stage content from Rumsey or other similar format to folder structure ready for accessioning.
This script is only known to be used by the Maps Accessioning team (Rumsey Map Center)
Full documentation of how it is used is here (which needs to be updated if this script moves):
https://consul.stanford.edu/pages/viewpage.action?pageId=146704638

Iterate through each row in the supplied CSV manifest, find files, generate contentMetadata and symlink to new location.
Note: filenames must match exactly (no leading 0s) but can be in any sub-folder

Run with:

```
RAILS_ENV=production bin/prepare_content INPUT_CSV_FILE.csv FULL_PATH_TO_CONTENT FULL_PATH_TO_STAGING_AREA [--no-object-folders] [--report] [--content-metadata] [--content-metadata-style map]
```

e.g.:

```
RAILS_ENV=production bin/prepare_content.rb /maps/ThirdParty/Rumsey/Rumsey_Batch1.csv /maps/ThirdParty/Rumsey/content /maps/ThirdParty/Rumsey [--no-object-folders] [--report] [--content-metadata] [--content-metadata-style map]
```

The first parameter is the input CSV (with columns labeled "Object", "Image", and "Label" (image is the filename, object is the object identifier which can be turned into a folder)
second parameter is the full path to the content folder that will be searched (i.e. the base content folder)
Note: files will be searched iteratively through all sub-folders of the base content folder
third parameter is optional and is the full path to a folder to stage (i.e. symlink) content to - if not provided, will use same path as csv file, and append "staging"

if you set the --report switch, it will only produce the output report, it will not symlink any files
if you set the --content-metadata switch, it will only generate content metadata for each object using the log file for successfully found files, assuming you also have columns in your input CSV labeled "Druid", "Sequence" and "Label"
if you set the --no-object-folders switch, then all symlinks will be flat in the staging directory (i.e. no object level folders) -- this requires all filenames to be unique across objects, if left off, then object folders will be created to store symlinks
note that file extensions do not matter when matching

## Data [Model](Model)

Pre-Assembly has a fairly simple [data model](db/schema.rb) based on three types of objects:

* *User*: a SUL staff person who is able to log in, based on configuration in [Puppet](https://github.com/sul-dlss/puppet/blob/production/hieradata/node/sul-preassembly-prod.stanford.edu.eyaml)
* *BatchContext*: includes details about a particular type of batch load, including where the data lives, who created it, the type of batch load, etc. This is also known as a "Project" in the user interface.
* *JobRun*: represents a specific batch load run using information from the BatchContext. These jobs are picked up by an asynchronous Sidekiq job when requested by the user. The job can be a full run, which submits the data to the [dor-services-app](https://github.com/sul-dlss/dor-services-app) API, or simply a "discovery report" which checks that the data and configuration look correct.
* *GlobusDestination*: represents a user and created_at timestamp for creating a Globus directory that will be associated with a BatchContext.

A *User* can have multiple *BatchContext*s and a *BatchContext* can have multiple *JobRun*s. When a user chooses to run or rerun a job in the user interface a new *JobRun* is created using the same *BatchContext*.

## Reset Process (for QA/Stage)

### Steps

1. [Reset the database](https://github.com/sul-dlss/DeveloperPlaybook/blob/main/best-practices/db_reset.md)
2. Delete the staging directory: `rm -fr /dor/assembly/*`
3. Delete the job artifacts output directory: `rm -fr /dor/preassembly/*`
4. To test, run the `preassembly_*_spec.rb` integration tests.
