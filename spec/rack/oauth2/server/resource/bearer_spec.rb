require 'spec_helper.rb'

describe Rack::OAuth2::Server::Resource::Bearer do
  let(:app) do
    Rack::OAuth2::Server::Resource::Bearer.new(simple_app) do |request|
      case request.access_token
      when 'valid_token'
        # nothing to do
      when 'insufficient_scope_token'
        request.insufficient_scope!
      else
        request.invalid_token!
      end
    end
  end
  let(:access_token) { env[Rack::OAuth2::Server::Resource::Bearer::ACCESS_TOKEN] }
  let(:request) { app.call(env) }
  subject { app.call(env) }

  shared_examples_for :non_oauth2_request do
    it 'should skip OAuth 2.0 authentication' do
      status, header, response = request
      status.should == 200
      access_token.should be_nil
    end
  end
  shared_examples_for :authenticated_request do
    it 'should be authenticated' do
      status, header, response = request
      status.should == 200
      access_token.should == 'valid_token'
    end
  end
  shared_examples_for :unauthorized_request do
    it 'should be unauthorized' do
      status, header, response = request
      status.should == 401
      header['WWW-Authenticate'].should include 'Bearer'
      access_token.should be_nil
    end
  end
  shared_examples_for :bad_request do
    it 'should be unauthorized' do
      status, header, response = request
      status.should == 400
      access_token.should be_nil
    end
  end

  context 'when no access token is given' do
    let(:env) { Rack::MockRequest.env_for('/protected_resource') }
    it_behaves_like :non_oauth2_request
  end

  context 'when valid_token is given' do
    context 'when token is in Authorization header' do
      let(:env) { Rack::MockRequest.env_for('/protected_resource', 'HTTP_AUTHORIZATION' => 'Bearer valid_token') }
      it_behaves_like :authenticated_request
    end

    context 'when token is in params' do
      let(:env) { Rack::MockRequest.env_for('/protected_resource', :params => {:bearer_token => 'valid_token'}) }
      it_behaves_like :authenticated_request
    end
  end

  context 'when invalid_token is given' do
    context 'when token is in Authorization header' do
      let(:env) { Rack::MockRequest.env_for('/protected_resource', 'HTTP_AUTHORIZATION' => 'Bearer invalid_token') }
      it_behaves_like :unauthorized_request
    end

    context 'when token is in params' do
      let(:env) { Rack::MockRequest.env_for('/protected_resource', :params => {:bearer_token => 'invalid_token'}) }
      it_behaves_like :unauthorized_request
    end
  end

  context 'when multiple access_token is given' do
    context 'when token is in Authorization header and params' do
      let(:env) do
        Rack::MockRequest.env_for(
          '/protected_resource',
          'HTTP_AUTHORIZATION' => 'Bearer valid_token',
          :params => {:bearer_token => 'valid_token'}
        )
      end
      it_behaves_like :bad_request
    end
  end

  context 'when OAuth 1.0 request' do
    context 'when token is in Authorization header' do
      let(:env) do
        Rack::MockRequest.env_for(
          '/protected_resource',
          'HTTP_AUTHORIZATION' => 'OAuth oauth_consumer_key="key" oauth_token="token" oauth_signature_method="HMAC-SHA1" oauth_signature="sig" oauth_timestamp="123456789" oauth_nonce="nonce"'
        )
      end
      it_behaves_like :non_oauth2_request
    end

    context 'when token is in params' do
      let(:env) do
        Rack::MockRequest.env_for('/protected_resource', :params => {
          :oauth_consumer_key => 'key',
          :oauth_token => 'token',
          :oauth_signature_method => 'HMAC-SHA1',
          :oauth_signature => 'sig',
          :oauth_timestamp => 123456789,
          :oauth_nonce => 'nonce'
        })
      end
      it_behaves_like :non_oauth2_request
    end
  end

  describe 'realm' do
    let(:env) { Rack::MockRequest.env_for('/protected_resource', 'HTTP_AUTHORIZATION' => 'Bearer invalid_token') }

    context 'when specified' do
      let(:realm) { 'server.example.com' }
      let(:app) do
        Rack::OAuth2::Server::Resource::Bearer.new(simple_app, realm) do |request|
          request.unauthorized!
        end
      end
      it 'should use specified realm' do
        status, header, response = request
        header['WWW-Authenticate'].should include "Bearer realm=\"#{realm}\""
      end
    end

    context 'otherwize' do
      it 'should use default realm' do
        status, header, response = request
        header['WWW-Authenticate'].should include "Bearer realm=\"#{Rack::OAuth2::Server::Resource::Bearer::DEFAULT_REALM}\""
      end
    end
  end
end