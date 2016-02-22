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
  module Team
    class Resource < Chef::Resource
      include Poise(parent: :github_organization)
      provides(:github_team)

      default_action(:create)
      actions(:create, :delete)

      attribute(:description, kind_of: String)
      attribute(:repositories, kind_of: Array, default: [])
      attribute(:permission, equal_to: ['pull', 'push', 'admin'])
      attribute(:privacy, equal_to: ['secret', 'closed'])
      attribute(:members, kind_of: Array, default: [])
      attribute(:purge_unknown_members, equal_to: [true, false], default: lazy { parent.purge_unknown_members })
      attribute(:purge_unknown_repositories, equal_to: [true, false], default: lazy { parent.purge_unknown_repositories })

      # in whyrun there is a chance we won't have our gem dependencies installed
      def whyrun_supported?
        false
      end

      def client
        parent.client
      end

      def organization
        parent.organization_name
      end

      def permission_hash
        case permission
        when 'admin'
          {pull: true, push: true, admin: true}
        when 'push'
          {pull: true, push: true, admin: false}
        when 'pull'
          {pull: true, push: false, admin: false}
        end
      end
    end

    class Provider < Chef::Provider
      include Poise
      provides(:github_team)

      def action_create
        if new_resource.parent.has_team?(new_resource.name)
          update_team
        else
          create_team
        end
      end

      def action_delete
        if new_resource.parent.has_team?(new_resource.name)
          delete_team
        end
      end

      private

      def current_team
        @current_team ||= new_resource.client.organization_teams(new_resource.organization).find{|t| t[:name] == new_resource.name }
      end

      def create_team
        obj = { name: new_resource.name }
        [ :description, :permission, :privacy ].each do |attr|
          if new_resource.send(attr)
            obj[attr] = new_resource.send(attr)
          end
        end

        converge_by "create_team #{new_resource.name}" do
          new_resource.client.create_team(new_resource.organization, obj)
        end

        new_resource.members.each do |member|
          add_team_member(member)
        end

        new_resource.repositories.each do |repo|
          add_team_repo(repo)
        end
      end

      def delete_team
        converge_by "delete_team #{new_resource.name}" do
          res = new_resource.client.delete_team(current_team[:id])
          unless res
            raise RuntimeError, "could not delete_team: #{new_resource.name}"
          end
        end
      end

      def update_team
        Chef::Log.debug("current_team: #{current_team}")
        Chef::Log.debug("current_team[:id]: #{current_team[:id]}")

        current_team_members = new_resource.client.team_members(current_team[:id])
        current_team_repositories = new_resource.client.team_repositories(current_team[:id])
        current_members = current_team_members.map {|member| member[:login] }
        current_repos = current_team_repositories.map {|repo| repo[:full_name] }

        members_to_add = new_resource.members - current_members
        Chef::Log.debug("members: #{new_resource.members}")
        Chef::Log.debug("current_members: #{current_members}")

        members_to_purge = current_members - new_resource.members
        Chef::Log.debug("members_to_add: #{members_to_add}")
        Chef::Log.debug("members_to_remove: #{members_to_purge}")

        repos_to_add = new_resource.repositories - current_repos
        repos_to_purge = current_repos - new_resource.repositories
        Chef::Log.debug("repos_to_add: #{repos_to_add}")
        Chef::Log.debug("repos_to_purge: #{repos_to_purge}")

        repos_to_update = []
        current_team_repositories.each do |repo|
          if repo[:permissions].to_h != new_resource.permission_hash
            repos_to_update << repo[:full_name]
          end
        end

        obj = {}
        [ :description, :permission, :repositories, :privacy ].each do |attr|
          val = new_resource.send(attr)
          if val and current_team[attr] != val
            obj[attr] = val
          end
        end

        unless obj.empty?
          converge_by "update_team #{new_resource.name}" do
            new_resource.client.update_team(current_team[:id], obj)
          end
        end

        members_to_add.each do |member|
          add_team_member(member)
        end

        if new_resource.purge_unknown_members
          members_to_purge.each do |member|
            remove_team_member(member)
          end
        end

        repos_to_add.each do |repo|
          add_team_repo(repo)
        end

        repos_to_update.each do |repo|
          add_team_repo(repo)
        end

        if new_resource.purge_unknown_repositories
          repos_to_purge.each do |repo|
            remove_team_repo(repo)
          end
        end
      end

      def add_team_member(member)
        converge_by "add_team_membership for #{member}" do
          res = new_resource.client.add_team_membership(current_team[:id], member)
          unless res
            raise RuntimeError, "did not add_team_membership for #{member} with response #{res}"
          end
        end
      end

      def remove_team_member(member)
        converge_by "add_team_membership for #{member}" do
          res = new_resource.client.remove_team_membership(current_team[:id], member)
          unless res
            raise RuntimeError, "did not add_team_membership for #{member} with response #{res}"
          end
        end
      end

      def add_team_repo(repo)
        converge_by "add_team_repository for #{repo}" do
          options = { permission: new_resource.permission }
          res = new_resource.client.add_team_repository(current_team[:id], repo, options)
          unless res
            raise RuntimeError, "could not add_team_repository for #{repo} with response #{res}"
          end
        end
      end

      def remove_team_repo(repo)
        converge_by "remove_team_repository for #{repo}" do
          res = new_resource.client.remove_team_repository(current_team[:id], repo)
          unless res
            raise RuntimeError, "could not remove_team_repository for #{repo} with response #{res}"
          end
        end
      end
    end
  end
end
