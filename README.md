# Pre-Assembly
[![Build Status](https://travis-ci.org/sul-dlss/pre-assembly.svg?branch=master)](https://travis-ci.org/sul-dlss/pre-assembly)
[![Coverage Status](https://coveralls.io/repos/github/sul-dlss/pre-assembly/badge.svg?branch=master)](https://coveralls.io/github/sul-dlss/pre-assembly?branch=master)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpre-assembly.svg)](https://badge.fury.io/gh/sul-dlss%2Fpre-assembly)

This is a Ruby implementation of services needed to prepare objects to be
assembled and then accessioned into the SUL digital library.

## Basics

`Pre-Assembly` is a Rails web-app at https://sul-preassembly-prod.stanford.edu/.  There is a link in the upper right to "Usage Instructions" which goes to the github wiki pages: https://github.com/sul-dlss/pre-assembly/wiki.

## Deployment

Deploy the Web app version in the usual capistrano manner:

```bash
cap stage deploy
cap prod deploy
```

See the `Capfile` for more info.


## Setting up code for local development

Clone project.
```bash
git clone git@github.com:sul-dlss/pre-assembly.git
cd pre-assembly
```

## Prerequisites

### Get needed gems

```bash
bundle install
```

#### Redis/Resque

The pre-assembly app uses Resque backed by Redis for job queueing.  In order to run the tests or run the
webapp locally, you will need to have Redis running.  On MacOSX, use `homebrew` to install:

```bash
brew install redis
```

and start as needed (if not running as a background process):

```bash
redis-server /usr/local/etc/redis.conf
```

See https://redis.io/ for other installation instructions and information.

#### exiftool

You need `exiftool` on your system in order to successfully run all of the tests.

On RHEL, download latest version from:  http://www.sno.phy.queensu.ca/~phil/exiftool

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

## Running tests

```bash
bundle exec rspec
```

## Local development

Just the usual:

```bash
bundle exec rails server
```

When running the application in development mode, it will use a default sunet_id (`'tmctesterson'`) for
its sessions. To override that behavior and specify an alternate user, you can manually specify the `REMOTE_USER`
environment variable at startup, like so:

```bash
REMOTE_USER="ima_user" bundle exec rails server
```

Because the application looks for user info in an environment variable, and because local dev environments don't have
an Apache module setting that environment variable per request based on headers from Webauth/Shibboleth, dev just always
sets a single value in that env var at start time.  So laptop dev instances basically only allow one fake login at a time.

## Post Accessioning Reports

Use [Argo](https://argo.stanford.edu/).

## Manifests

Manifests are a way of indicating which objects you will be accessioning. A
manifest file is a CSV, UTF-8 encoded file and works for projects which have
one file per object (where container = one file), or projects with many
files per object (where container = folder).

**WARNING**: if you export from Microsoft Excel, you may not get a properly
formatted UTF-8 CSV file. You should open any CSV that has been exported from
Excel in a text editor and re-save it in proper UTF-8 files (e.g. Atom, Sublime,
or TextMate).

There are a few columns in the manifest, with two required:

- `container`: container name (either filename or folder name) -- **required**
- `druid`: druid of object -- **required**
- `sourceid`: source ID
- `label`: label

The druids should include the "druid:" prefix (e.g. "druid:oo000oo0001" instead of "oo000oo0001").

The first line of the manifest is a header and specifies the column names.
Column names should not have spaces and it is easiest if they are all lower
case. These columns are used to indicate which file goes
with the object. If the container column specifies a filename, it should be
relative to the manifest file itself. You can have additional columns in your
manifest which can be used to create descriptive metadata for each object. See
the section below for more details on how this works.

The druid column **must** be called `"druid"`.

See the sample manifest file [`TEMPLATE_manifest.csv`](spec/test_data/exemplar_templates/manifest_template/TEMPLATE_manifest.csv).

## Descriptive Metadata

If descriptive metadata is supplied in a source known to common accessioning
(currently Symphony), then no action is required during
pre-assembly other than ensuring your DRUIDs and/or barcodes match the ones in Symphony.

If you are supplying a manifest file instead of using object discovery via
file system crawling, then you can also create a descriptive metadata MODs
file for each object using content supplied in the manifest.  By creating a
template XML MODS file, placing with your YAML configuration file and ensuring
it's filename is indicated in your YAML configuration, you can tell
pre-assembly to generate a MODs file per object.  The generated MODs file
should be called "descMetadata.xml" and will be staged alongside the content.
This file is automatically picked up during common accessioning.

The MODs file is generated by taking the XML template you supply, and filling
in any `[[field]]` values in the template with the corresponding column from
the manifest.

For example, if your template has:
```xml
<mods><title>[[description]]</title></mods>
```

and you have a column called "description" in your manifest and you have a row
with a value of "picture of me", you will get that value filled into your
template for that specific object:

```xml
<mods><title>picture of me</title></mods>
```

In addition, the entire MODs template is passed through an ERB parser,
allowing you to utilize Ruby code in the template using the standard
[ERB](http://ruby-doc.org/stdlib-1.9.3/libdoc/erb/rdoc/ERB.html) template `<%
%>` syntax.  This can be used to peform more complex operations.  If you
utilize Ruby code, you will have access to a special local variable called
'manifest_row', which is a hash of values for that row in the manifest, keyed
off the column names.  For example:

```xml
<mods><title><%= manifest_row[:description] %></title></mods>
```

To use a different character encoding in your ERB template, put the following
at the top of your `template.xml`:

```xml
<%#-*- coding: UTF-8 -*-%>
<?xml version="1.0" encoding="UTF-8"?>
```

## Accession of Specific Objects

Using a manifest:

1.  Create a new manifest with only the objects you need accessioned.
2.  Create a new project config YAML file referencing the new manifest and
    write to a new progress log file.
3.  Run pre-assembly.
