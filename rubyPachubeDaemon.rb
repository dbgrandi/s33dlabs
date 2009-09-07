#!/usr/bin/env ruby
#
# This opens a connection on a serial port, listens for data from an arduino board with
# different sensors on it, and stores the data to a hash object. At the same time,
# we have a thread that sleeps for 2 minutes, then wakes up and sends data up to pachube.
#
require 'open-uri'
require 'net/http'
require 'erb'
#require 'rubygems'
require 'serialport'

PACHUBE_SERVER = "www.pachube.com"
PACHUBE_BASE_URL = "https://#{PACHUBE_SERVER}/api/"
API_KEY = "09be3023173fed3dd005872a42611843dbafb1b7c25597adf57f45795a60afe9"
PACHUBE_FEED_ID = 2396
PACHUBE_FEED_URI = "#{PACHUBE_BASE_URL}#{PACHUBE_FEED_ID}.xml"

eeml_template = %q{
<?xml version="1.0" encoding="UTF-8"?>
<eeml xmlns="http://www.eeml.org/xsd/005">
<environment>
<% values.keys.each do |key| %>
<data id="<%= key.to_i %>">
<value><%= values[key.to_i] %></value>
</data>
<% end %>
</environment>
</eeml>
}.gsub(/^  /, '')

sensor_ids = Hash.new
sensor_ids['Humidity'] = 0
sensor_ids['Temp']     = 1
sensor_ids['Light']    = 2
sensor_ids['Pressure'] = 3

values = Hash.new

#serialDevice = `ls /dev/cu.usbserial*`
#puts "Opening #{serialDevice.strip}"
#sp = SerialPort.new "#{serialDevice.strip}", 9600
sp = SerialPort.new "/dev/ttyS3"

puts "Opened #{sp}"

#throw out the first line to get rid of trash partial lines
puts "garbage line = #{sp.readline}"
 
while values.keys.size < 4
  a = (sp.readline).split ":"
  values[ sensor_ids[a[0]] ] = a[1].to_i
end

last_post = Time.now
post=0

while true
  a = (sp.readline).split ":"
  values[ sensor_ids[a[0]] ] = a[1].to_i

  if Time.now > last_post + 60 
    parser = ERB.new(eeml_template)
    payload = parser.result.gsub("\n","")
  
    client = Net::HTTP.new(PACHUBE_SERVER)
    response = client.send_request("PUT", PACHUBE_FEED_URI, payload,
                { 'X-PachubeApiKey' => API_KEY,
                  'Content-Length'  => payload.length.to_s
                })

    puts "#{Time.now} posted reading #{post}"
    post = post+1
    last_post = Time.now
  end

end

