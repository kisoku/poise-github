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

      attribute(:organization_name, kind_of: String, name_attribute: true)
      attribute(:purge_unknown_teams, equal_to: [true, false], default: lazy { node['poise-github']['purge_unknown_teams'] })
      attribute(:purge_unknown_members, equal_to: [true, false], default: lazy { node['poise-github']['purge_unknown_members'] })
      attribute(:purge_unknown_repositories, equal_to: [true, false], default: lazy { node['poise-github']['purge_unknown_repositories'] })

      def whyrun_supported?
        false
      end

      def teams
        subresources.select {|res| res.is_a?(PoiseGithub::Team::Resource)}
      end

      def client
        parent.client
      end

      def has_team?(team_name)
        not client.organization_teams(organization_name).find {|t| t[:name] == team_name }.nil?
      end
    end


    class Provider < Chef::Provider
      include Poise
      provides(:github_organization)

      def action_create
        # can't create orgs via api!
        current_teams = new_resource.client.organization_teams(new_resource.organization_name)
        current_team_names = current_teams.map {|t| t[:name] }
        defined_team_names = new_resource.teams.map {|t| t.name }

        teams_to_purge = current_team_names - defined_team_names

        if new_resource.purge_unknown_teams
          teams_to_purge.each do |team|
            github_team "team".run_action(:delete)
          end
        end
      end

      def action_delete
        # can't delete orgs via api!
      end

      private
    end
  end
end
