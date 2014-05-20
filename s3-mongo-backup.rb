#!/usr/bin/ruby
#
# Using master/slave configuration it's better to add some logic.

require 'date'
require 'fileutils'
require 'mongo'

include Mongo

$mongo = MongoClient.new
$mongo_db = $mongo["local"]

# CONFIGURATION 
SRCDIR    = '/tmp/s3backups'
BUCKET    = '<BUCKET>'
DESTDIR   = '<DESTINATION-DIR>'

MONGO_DIR = '/var/mongo'
S3CMD     = '/usr/bin/s3cmd'
# END CONFIGURATION

# Find a Slave with lowest id, it will do the backup
slave = $mongo_db.eval("rs.status()")["members"].inject({"_id" => -1}) do |inj, item|
  if item["_id"] > inj["_id"] and item["state"] == 2
    inj = item
  end
  inj
end

if slave["self"]
  # do your job
  today = Date.today.to_s

  unless File.directory? SRCDIR then
    FileUtils.mkdir_p SRCDIR
  end

  src = "mongo-#{today}.tar.bz2"
  dst = "s3://#{BUCKET}/#{DESTDIR}/"
  Dir.chdir(SRCDIR) do
    puts "Calling mongodump..."
    %x( mongodump )
    puts "Calling tar.."
    %x( tar cjf #{src} dump/)
    puts "Uploading to S3.."
    %x( /usr/bin/s3cmd put #{src} #{dst} )
  end
  FileUtils.rm_rf( SRCDIR )
end

puts "Done!"
