include_recipe 'poise-github::default'

github 'github.com'
github_organization 'kisoku-cookbooks' do
  owners %w(
    kisoku
  )
  members %w( coderanger )
  purged_members %w(
    kisoku-test
  )
end

github_team 'test2' do
  action :delete
end
