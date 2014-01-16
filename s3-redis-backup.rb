#!/usr/bin/ruby
#
# Using master/slave configuration it's better to add some logic.

require 'date'
require 'fileutils'
require 'socket'
require 'redis'

def redis
  $redis ||= Redis.new :port => 26379
end

# CONFIGURATION 
SRCDIR    = '/tmp/s3backups'
BUCKET    = '<BUCKET>'
DESTDIR   = '<DESTINATION-DIR>'

REDIS_DIR = '/var/redis'
S3CMD     = '/usr/bin/s3cmd'
# END CONFIGURATION


# Get local private IP address
@ip = Socket.ip_address_list.detect{ |iface| iface.ipv4_private? }.ip_address

redis.sentinel( :masters ).each do |m|

  master = Hash[ *m.flatten ]

  # skip if master
  next if master["ip"].eql? @ip

  runids = { }

  # cycle slaves for current master
  redis.sentinel( :slaves, master["name"] ).each do |s|

    slave = Hash[ *s.flatten ]

    # associate runid => ip_addr
    runids[ slave["runid"] ] = slave["ip"]

  end

  # skip if current slave is not the chosen one
  next unless runids[ runids.keys.max ].eql? @ip

  puts "Performing Redis backup for #{master['name']} master..."

  # do your job
  today = Date.today.to_s

  unless File.directory? SRCDIR then
    FileUtils.mkdir_p SRCDIR
  end

  rdb = "#{REDIS_DIR}/#{master['name']}.rdb"
  src = "#{SRCDIR}/#{master['name']}-#{today}.rdb"
  dst = "s3://#{BUCKET}/#{DESTDIR}/"

  FileUtils.cp rdb, src
  %x( /usr/bin/s3cmd put #{src} #{dst} )
  
  puts "Done!"

end
