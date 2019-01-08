# Pre-Assembly
[![Build Status](https://travis-ci.org/sul-dlss/pre-assembly.svg?branch=master)](https://travis-ci.org/sul-dlss/pre-assembly)
[![Coverage Status](https://coveralls.io/repos/github/sul-dlss/pre-assembly/badge.svg?branch=master)](https://coveralls.io/github/sul-dlss/pre-assembly?branch=master)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpre-assembly.svg)](https://badge.fury.io/gh/sul-dlss%2Fpre-assembly)

This is a Ruby implementation of services needed to prepare objects to be
assembled and then accessioned into the SUL digital library.

## Releases

See the [RELEASES](./RELEASES.md) list.

### Legacy

The legacy command-line version of this code is represented by the `v3-legacy` branch. That branch is deployed to `sul-lyberservices-test`
and `-prod`, and is still actively used by a small number of power users in the PSM group. Until the [desired functionality](https://github.com/sul-dlss/pre-assembly/issues/221) in the `v3-legacy` branch has been ported to the web application in `master`, we should continue to maintain the `v3-legacy` branch.

The contemporary `Pre-Assembly` is a rails web-app.

## Running the legacy application

### Documentation for the contemporary (web) app is in the wiki:  https://github.com/sul-dlss/pre-assembly/wiki

1.  Gather information about your project, including:
    *   The location of the materials.  You will need read access to this
        location from the servers you will be accessioning in (e.g. test and production).
    *   Confirm all objects are already registered.
    *   The location of any descriptive metadata.
    *   Whether you will be flattening the folder structure of each object
        when accessioning (e.g. discarding any folder structure provided to you in each object).
    *   The DRUID of the project's APO.
    *   The DRUID of the set object you will be associating your objects with (if any).
    *   If you are using a manifest file in CSV format and want to create
        descriptive metadata, create a MODs XML template.  See the
        "descriptive metadata" section below for more details.

2.  Create a project-configuration YAML file using the data you gathered
    above. Store this file in a location where it can be accessed by the
    server (test or production). You should create a YAML file for each
    environment specifying the parameters as appropriate. Use the convention
    of `projectname_environment.yaml`, e.g. `revs_test.yaml`. If you have
    multiple collections to associate your objects with, you will need to run
    in multiple batches with multiple YAML files. You can add your collection
    name to the end of each YAML filename to keep track (e.g. `revs_test_craig.yaml`)

    The YAML file can be stored anywhere that is accessible to the server you
    are running the code on. However, for simplicity, we recommend you store
    the YAML at the root of your bundle directory, or create a new project
    folder, place your YAML file into it and then place your bundle directory
    into your new project folder.

    Example:

    * Your content is on `/thumpers/dpgthumper-staing/Hummel`
    * Create a YAML file at `/thumpers/dpgthumper-staging/Hummel/hummel_test.yaml`
    * Move your content (if you can) into `/thumpers/dpgthumper-staging/Hummel/content`

    If you cannot move your content, be sure your YAML bundle discovery glob
    and/or regex are specific enough to correctly ignore your YAML file during
    discovery. Or, alternatively, place your YAML file in a location other
    than the bundle.

    * See [`TEMPLATE.yaml`](spec/test_data/exemplar_templates/TEMPLATE.yaml) for a fully documented example of a configuration file.
    * See [`reg_example.yaml`](spec/test_data/exemplar_templates/reg_example.yaml) for a specific example using a file system crawl.
    * TODO: link example using manifest.

3.  Check the permissions on the bundle directory, iteratively. You need read
    permissions on all the bundle directory folders and files. You need to
    have write permissions in the location you plan to write the log file too
    (often this cannot be the thumper drives since it is mounted as
    read-only).

4.  You may benefit from running some objects in a local or test environment.
    If your objects are already registered, this may require pre-registering a
    sample set in test as well as production using the same DRUIDs that are
    identified with your content. You may also have to move a small batch of
    test content to a location that is visible to the stage server.
    Since the thumper drives are not mounted on the test server, you can use
    the `/dor/content` mount on test for this purpose.

5.  Make sure you have an APO for your object, and that the
    administrativeMetadata data stream has the `<assemblyWF>` defined in it.
    If it does not, go to https://consul.stanford.edu/display/APO/Home and
    find the "Current FoXML APO template" link at the bottom of the page.
    Download and open the template, find the `<assembly>` node and copy it. Go
    to Fedora admin for each relevant environment (test/production) and this
    node to the administrativeMetadata stream. If you don't have this workflow
    defined in your APO, then the assembly robots will never operate and
    accessioning will not operate. This APO should be defined using the same
    DRUID in test and production if you intend to run in both locations.


# Legacy Project Notes

The assembly robots will automatically create jp2 derivates from any TIFFs,
JP2s, or JPEGs. If you are working on a legacy project that has JP2s already
that were generated from source TIFFs, you should **not** stage those files
during pre-assembly, or else you will end up with two JP2s for each TIFF. You
can do this by using a regex to exclude .JP2 files or by only staging certain
subfolders. If you do stage the JP2 files and they have the same filename as
the TIFF (but with a different extension) they will be kept as is (i.e. they
will NOT have JP2s re-generated from the source TIFFs). If you do stage the
JP2 files and they have a different basename than the TIFFs, they WILL be
re-generated, and you will end up with two copies, in two different resources.

## Deployment

```bash
cap dev deploy  # for lyberservices-dev
cap testing deploy  # for lyberservices-test
cap production deploy # for lyberservices-production
```

Enter the branch or tag you want deployed.

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

## Running the (contemporary web) application for local development

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

## Troubleshooting (the legacy application)

### Seeing an error like this when you try to run pre-assembly or a discovery report?
```
Psych::SyntaxError: (<unknown>): mapping values are not allowed in this
context at line 37 column 14
```
Its probably because your YAML configuration file is malformed. YAML is very
picky, particularly in tabs, spacing and other formatting trickeries.  You verify
your YAML file inside `rails console` or `irb`:
```ruby
yaml_config = '/full/path/to/your/config.yaml'
params = YAML.load(File.read yaml_config)
```

If you get a hash of values back, it parsed correctly.  If you get the
`Psych::SyntaxError`, it did not.  The line number referenced in the error
should help you locate the part of your file that is having issues.  Edit and
try loading the YAML again on the console to confirm.

1.  If you don't see all of your objects being discovered or no files are
    found in discovered objects, check the permissions on the bundle
    directory. You need read permissions on all the bundle directory folders
    and files.

3.  Be sure you have read access to the YAML file you created from the server
    you are running on.

6.  If you don't see JP2s being created (or recreated) for your content, this
    is probably due to one of the following problems:

    1.  The content metadata generated by pre-assembly didn't set a resource
        type or set a resource type other than "image" or "page". Assembly
        will only create jp2s for images containing in resources marked as
        "image" or "page". Pre-assembly will do this automatically for
        :simple_image and :simple_book projects, but check the output of the
        content metadata to be sure.

    2.  The image was not a mimetype of 'image/jpeg' or 'image/tiff'.  Any
        other mimetype will be ignored.

    3.  Your input image was corrupt or missing a color space profile.  This
        will usually cause the jp2-create robot to fail and throw an error in
        that workflow step.

    4.  You had an existing JP2 in the directory that matched a tiff or jpeg.
        In this case the jp2-create robot will not overwrite any existing
        files just to be safe.

    5.  You had an existing JP2 in the directory that matched a DPG style
        filename (e.g. if you had existing tiff called `xx000yy1111_00_01.tif`
        and a jp2 called `xx000yy1111_05_01.jp2`), you will not get another jp2
        from that tiff even though there would not be a filename clash, under
        the principle that it refers to the same image).

    It is possible to force add color profiles to a single image or all of the
    images in a given directory:

        source_img = Assembly::Image.new('/input/path_to_file.tif') # add to a single image
        source_img.add_exif_profile_description('Adobe RGB 1998')

    or

        Assembly::Images.batch_add_exif_profile_description('/full_path_to_tifs','Adobe RGB 1998') # add to multiple images

8.  If you see incorrect content metadata being generated, note that the 'Process : Content Type' tag for each
    existing object will be examined. If a known type is set in this tag, it
    will be used to create content metadata instead of the default set in
    [project_style](:content_structure). Check the tag for each object if the
    style is not matching what you have set in the YAML configuration file.
    Also note that if `content_md_creation[:style]` is set to 'none', then no
    content metadata will be generated.

## Post Accessioning Reports

Use [Argo](https://argo.stanford.edu/).

## Manifests (applicable to both the legacy command line app and the contemporary web app)

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
(currently MDToolkit or Symphony), then no action is required during
pre-assembly other than ensuring your DRUIDs and/or barcodes match the ones in
MDToolkit or Symphony.

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
