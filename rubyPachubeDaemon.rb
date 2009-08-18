#!/usr/bin/env ruby
#
# This opens a connection on a serial port, listens for data from an arduino board with
# different sensors on it, and stores the data to a hash object. At the same time,
# we have a thread that sleeps for 2 minutes, then wakes up and sends data up to pachube.
#
require 'open-uri'
require 'net/http'
require 'erb'
require 'rubygems'
require 'serialport'

PACHUBE_SERVER = "www.pachube.com"
PACHUBE_BASE_URL = "http://#{PACHUBE_SERVER}/api/"
API_KEY = "09be3023173fed3dd005872a42611843dbafb1b7c25597adf57f45795a60afe9"

eeml_template = %{
<?xml version="1.0" encoding="UTF-8"?>
<eeml xmlns="http://www.eeml.org/xsd/005">
  <environment>
	<% sensors.keys.each do |key| ->
    <data id="<%= key.to_i ->">
      <value><%= sensors['key'] -></value>
    </data>
  <% end ->
  </environment>
</eeml>
}.gsub(/^  /, '')

sensor_ids = Hash.new
sensor_ids['Humidity'] = 0
sensor_ids['Temp']     = 1
sensor_ids['Light']    = 2
sensor_ids['Pressure'] = 3

values = Hash.new

serialDevice = `ls /dev/cu.usbserial*`
puts "Opening #{serialDevice.strip}"
sp = SerialPort.new "#{serialDevice.strip}", 9600

last_post_to_pachube = Time.now - 60

puts "Opened #{sp}"

while values.keys.size < 4
  a = (sp.readline).split ":"
  values[ sensor_ids[a[0]] ] = a[1].to_i
end

while true
  a = (sp.readline).split ":"
  values[ sensor_ids[a[0]] ] = a[1].to_i

  if (Time.now - last_post_to_pachube > 60)
    payload = ERB.new(eeml_template)
    puts payload.result
    last_post_to_pachube = Time.now
  end
end