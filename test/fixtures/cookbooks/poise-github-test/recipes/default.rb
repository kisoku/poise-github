include_recipe 'poise-github::default'

github 'github.com'
github_organization 'kisoku-cookbooks' do
  owners %w(
    kisoku
  )
  members %w(
    coderanger
    kisoku-test
  )
end

github_team 'test2' do
  description 'test 2'
  members %w[
    kisoku
    coderanger
  ]
end
