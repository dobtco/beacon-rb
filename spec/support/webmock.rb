require 'webmock/rspec'

WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: ['www.example.com', 'codeclimate.com']
)
