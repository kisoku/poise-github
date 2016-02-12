require 'poise'

module PoiseGithub
  module Team
    class Resource < Chef::Resource
      include Poise(parent: :github_organization)
      provides(:github_team)

      default_action(:create)
      actions(:create, :delete)

      attribute(:description, kind_of: String)
      attribute(:repositories, kind_of: [Symbol, Array])
      attribute(:permission, equal_to: ['pull', 'push', 'admin'])
      attribute(:privacy, equal_to: ['secret', 'closed'])
      attribute(:members, kind_of: Array)
      attribute(:purge_unknown_members, equal_to: [true, false], default: true)

      def client
        parent.client
      end

      def organization
        parent.name
      end
    end

    class Provider < Chef::Provider
      include Poise
      provides(:github_team)

      def client
        new_resource.parent.client
      end

      def action_create
        if new_resource.parent.has_team?(new_resource.name)
          update_team
        else
          create_team
        end
      end

      def action_delete
      end

      private

      def create_team
        obj = { name: new_resource.name }
        [ :description, :permission, :repositories, :privacy ].each do |attr|
          if new_resource.send(attr)
            obj[attr] = new_resource.send(attr)
          end
        end
        current_team = new_resource.client.create_team(new_resource.organization, obj)

        new_resource.members.each do |member|
          new_resource.client.add_team_membership(current_team[:id], member)
        end
        new_resource.updated_by_last_action(true)
      end

      def update_team
        obj = {}
        current_team = new_resource.client.organization_teams(new_resource.organization).find{|t| t[:name] = new_resource.name }
        [ :description, :permission, :repositories, :privacy ].each do |attr|
          val = new_resource.send(attr)
          if val and current_team[attr] != val
            obj[attr] = val
          end
        end

        unless obj.empty?
          new_resource.client.update_team(current_team[:id], obj)
          new_resource.updated_by_last_action(true)
        end

        current_team_members = new_resource.client.team_members(current_team[:id])
        current_members = current_team_members.map {|member| member[:login] }

        members_to_add = new_resource.members - current_members
        members_to_purge = current_members - new_resource.members

        members_to_add.each do |added|
          new_resource.client.add_team_membership(current_team[:id], added)
          new_resource.updated_by_last_action(true)
        end

        if new_resource.purge_unknown_members
          members_to_purge.each do |purged|
            new_resource.client.remove_team_membership(current_team[:id], purged)
            new_resource.updated_by_last_action(true)
          end
        end
      end
    end
  end
end
