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
