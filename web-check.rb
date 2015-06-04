#!/usr/bin/env ruby
require 'rubygems'
require 'socket'
require 'json'
require 'sensu-plugin/check/cli'
require 'typhoeus'
require 'pp'

class MultiHTTPCheck < Sensu::Plugin::Check::CLI
  option :urls_file,
         :short => '-f FILE',
         :long => "--urls-file FILE",
         :default => '/etc/sensu/conf.d/urls.txt'

  option :concurrence,
         :short => '-c C',
         :long => "--concurrence C",
         :default => 10

  option :handler,
         :short => '-l HANDLER',
         :long => '--handler HANDLER',
         :default => 'default'

  def sensu_client_socket(msg)
   u = UDPSocket.new
   u.send(msg + "\n", 0, '127.0.0.1', 3030)
  end

  def send_ok(check_name, msg)
   d = { 'name' => check_name, 'status' => 0, 'output' => 'OK: ' + msg, 'handler' => config[:handler] }
   sensu_client_socket d.to_json
  end

  def send_warning(check_name, msg)
   d = { 'name' => check_name, 'status' => 1, 'output' => 'WARNING: ' + msg, 'handler' => config[:handler] }
   sensu_client_socket d.to_json
  end

  def send_critical(check_name, msg)
   d = { 'name' => check_name, 'status' => 2, 'output' => 'CRITICAL: ' + msg, 'handler' => config[:handler] }
   sensu_client_socket d.to_json
  end

  def parse_response(response)
  	check_name = response.request.url.gsub('http://', '').gsub('https://', '').gsub('/', '-')

    if( response.timed_out? )
      send_warning "WEB_#{check_name}", "#{response.request.url} TIMED OUT"
    elsif ( response.code == 200 )
      send_ok "WEB_#{check_name}", "#{response.request.url} is returning #{response.code}"
    else
      send_critical "WEB_#{check_name}", "#{response.request.url} is returning #{response.code}"
    end

	end


  def run
    hydra = Typhoeus::Hydra.new(max_concurrency: config[:concurrence])
    requests = Array.new

    IO.foreach(config[:urls_file]) do |url|
      url = url.gsub("\n", '')
      request = Typhoeus::Request.new(url, followlocation:true, cache_ttl:0)
      request.on_complete{ |response| parse_response(response) }
      hydra.queue(request)
    end


    hydra.run

   ok "WEBCHECKS RAN OK"

end

end
