# poise-github

Manage your GitHub organizations with Poise.

## Requirements

Poise-github only works on Chef 12 and up due to it's dependency on Poise 2.x

## Usage

```ruby
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

## Working with GitHub Enterprise

```ruby
github 'ghe.example.com' do
  api_endpoint 'https://ghe.example.com/api/v3/'
  login 'ba_baracus'
  access_token 'ipitythefoolthatusesthistoken'
end
```
