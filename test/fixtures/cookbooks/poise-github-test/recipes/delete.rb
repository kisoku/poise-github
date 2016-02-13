include_recipe 'poise-github::default'

github 'github.com'
github_organization 'kisoku-cookbooks'

github_team 'test2' do
  action :delete
end
