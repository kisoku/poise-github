#
# Copyright 2016, Mathieu Sauve-Frankel
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


require 'poise'

module PoiseGithub
  module Github
    class Resource < Chef::Resource
      include Poise(container: true)

      provides(:github)
      default_action(:nothing)

      attribute(:api_endpoint, kind_of: String)
      attribute(:login, kind_of: String, required: true, default: lazy { node['poise-github']['login'] })
      attribute(:access_token, kind_of: String, required: true, default: lazy { node['poise-github']['access_token'] })

      def whyrun_supported?
        false
      end

      def client
        require 'octokit'

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
