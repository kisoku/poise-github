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
  module Organization
    class Resource < Chef::Resource
      include Poise(container: true, parent: :github)
      provides :github_organization

      default_action(:create)

      def teams
        subresources.select {|res| res.is_a?(PoiseGithub::Team::Resource)}
      end

      def client
        parent.client
      end

      def has_team?(team_name)
        not client.organization_teams(name).find {|t| t[:name] == team_name }.nil?
      end
    end


    class Provider < Chef::Provider
      include Poise
      provides(:github_organization)

      def action_create
      end

      def action_delete
      end

      private
    end
  end
end
