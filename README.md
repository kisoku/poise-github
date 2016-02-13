# poise-github

Manage your GitHub organizations with Poise.

## Usage

```
github 'github.com' do
  login 'ba_baracus'
  access_token 'ipitythefoolthatusesthistoken'
end

github_organization 'my-org'

github_team 'a-team' do
  permission 'admin'
  privacy 'closed'
  members %w[
    hannibal
    face
    ba_baracus
    murdock
  ]
  repositories %w[
    my-org/sucka
  ]
end
```
