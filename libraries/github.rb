require 'poise'
require 'octokit'
require 'faraday'

module PoiseGithub
  module Github
    class Resource < Chef::Resource
      include Poise(container: true)

      provides(:github)
      default_action(:nothing)

      attribute(:api_endpoint, kind_of: String)
      attribute(:login, kind_of: String, required: true, default: lazy { node['poise-github']['login'] })
      attribute(:access_token, kind_of: String, required: true, default: lazy { node['poise-github']['access_token'] })

      def client
        args = {
          login: login,
          access_token: access_token,
          middleware: middleware
        }
        args[:access_token] = access_token if access_token

        @client ||= Octokit::Client.new(
          args
        )
      end

      private

      def middleware
        require 'faraday-http-cache'

        @middleware ||= Faraday::RackBuilder.new do |builder|
          builder.use Faraday::HttpCache
          builder.use Octokit::Response::RaiseError
          builder.adapter Faraday.default_adapter
        end
      end
    end

    class Provider < Chef::Provider
      include Poise

      provides(:github)

      def action_nothing
      end
    end
  end
end
