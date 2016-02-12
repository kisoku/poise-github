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
        new_resource.client.create_team(new_resource.organization, obj)
        new_resource.updated_by_last_action(true)
      end

      def update_team
        obj = {}
        current_team = new_resource.client.organization_teams(new_resource.parent).find{|t| t[:name] = new_resource.name }
        [ :description, :permission, :repositories, :privacy ].each do |attr|
          if current_team[attr] != new_resource.send(attr)
            obj[attr] = new_resource.send(attr)
          end
        end
        unless obj.empty?
          new_resource.client.update_team(current_team[:id], obj)
          new_resource.updated_by_last_action(true)
        end
      end
    end
  end
end
