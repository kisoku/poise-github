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
      attribute(:members, kind_of: Array, default: [])
      attribute(:owners, kind_of: Array, default: [])
      attribute(:purged_members, kind_of: Array, default: [])
      attribute(:purge_unknown_members, equal_to: [true, false], default: lazy { node['poise-github']['purge_unknown_members'] })
      attribute(:purge_unknown_repositories, equal_to: [true, false], default: lazy { node['poise-github']['purge_unknown_repositories'] })
      attribute(:purge_unknown_teams, equal_to: [true, false], default: lazy { node['poise-github']['purge_unknown_teams'] })

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
        purge_members
        update_owners
        update_members
        update_teams
      end

      def action_delete
        # can't delete orgs via api!
      end

      private

      def org_members(**opts)
        new_resource.client.organization_members(new_resource.organization_name, **opts)
      end

      def current_owners
        current_owners = org_members(role: 'admin').map {|u| u[:login] }
        Chef::Log.info "current_owners: #{current_owners}"
        current_owners
      end

      def current_members
        current_members = org_members(role: 'member').map {|u| u[:login] }
        Chef::Log.info "current_members: #{current_members}"
        current_members
      end

      def update_member?(member, role: 'member')
        begin
          current_membership = new_resource.client.org_membership(
            new_resource.organization_name,
            user: member
          )

          # if role has changed update the membership
          # this should catch pending requests as well as existing users
          if current_membership[:role] != role
            true
          # do not re-invite users that have pending invitations or are active
          elsif current_membership[:state] == 'pending' || current_membership[:state] == 'active'
            false
          else
            # NOTREACHED default to false to be safe
            Chef::Log.warn 'update_member?: this is supposed to be NOTREACHED'
            false
          end
        # users that have no membership will throw a 404
        rescue Octokit::NotFound
          true
        # re-raise any other type of exception
        rescue StandardError
          raise
        end
      end

      def update_org_member(member, role: 'member')
        if update_member?(member, role: role)
          converge_by "update_organization_membership for #{member}" do
            new_resource.client.update_organization_membership(
              new_resource.organization_name,
              user: member,
              role: role
            )
          end
        end
      end

      def remove_org_member(member)
        converge_by "remove_organization_membership for #{member}" do
          new_resource.client.remove_organization_membership(
            new_resource.organization_name,
            user: member
          )
        end
      end

      def purge_members
        # This needs to be explicitely tracked, as github has no mechanism to
        # receive a list of members in a pending state, purging undefined users
        # will not catch these pending accounts and leave the invites active.
        # Explicitely defining which users to purge works everytime though
        members_to_purge = new_resource.purged_members
        Chef::Log.debug("members_to_purge: #{members_to_purge}")
        members_to_purge.each do |member|
          remove_org_member(member)
        end
      end

      def update_owners
        new_owners = new_resource.owners - current_owners
        Chef::Log.debug("new_owners: #{new_owners}")
        new_owners.each do |owner|
          update_org_member(owner, role: 'admin')
        end
      end

      def update_members
        new_members = new_resource.members - current_members
        Chef::Log.debug("new_members: #{new_members}")
        new_members.each do |member|
          update_org_member(member)
        end
      end

      def update_teams
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
    end
  end
end
