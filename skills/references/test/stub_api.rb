# frozen_string_literal: true

# A stand-in for dbb's Agent Reference API, for the bats suite: listens on a
# free local port, writes the port to PORT_FILE, and appends one JSON line per
# request (path, Authorization header) to LOG_FILE. Nothing leaves the host.
#
# Usage: ruby stub_api.rb PORT_FILE LOG_FILE

require 'json'
require 'socket'

port_file, log_file = ARGV
server = TCPServer.new('127.0.0.1', 0)
File.write(port_file, server.addr[1].to_s)

TOKEN = 'Bearer good-token'

def reply(client, status, body)
  text = body.is_a?(String) ? body : JSON.generate(body)
  client.write("HTTP/1.1 #{status}\r\nContent-Type: application/json\r\n" \
               "Content-Length: #{text.bytesize}\r\nConnection: close\r\n\r\n#{text}")
end

def error(code, message) = { error: { code:, message: } }

def route(path, auth)
  return ['401 Unauthorized', error('unauthorized', 'missing or invalid token')] unless auth == TOKEN

  case path
  when %r{\A/api/v1/references(\?.*)?\z}
    ['200 OK', { references: [{ id: 42, title: 'Tinian' }], pagination: { page: 1, count: 1 } }]
  when %r{\A/api/v1/references/42\z} then ['200 OK', { reference: { id: 42, title: 'Tinian' } }]
  when %r{\A/api/v1/references/42/content\z} then ['200 OK', { id: 42, content: 'the cached page' }]
  when %r{\A/api/v1/references/43/content\z} then ['409 Conflict', error('no_content', 'no cached snapshot')]
  when %r{\A/api/v1/references/44\z} then ['500 Internal Server Error', '<html>oops</html>']
  else ['404 Not Found', error('not_found', 'no reference with that id')]
  end
end

loop do
  client = server.accept
  path = client.gets.to_s.split[1]
  headers = {}
  while (line = client.gets) && line != "\r\n"
    name, value = line.split(':', 2)
    headers[name.downcase] = value.to_s.strip
  end
  File.open(log_file, 'a') { it.puts JSON.generate(path:, authorization: headers['authorization']) }
  reply(client, *route(path, headers['authorization']))
  client.close
end
