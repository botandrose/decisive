# Decisive

DSL for rendering CSVs

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'decisive'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install decisive

## Usage

Example usage:

```ruby
# app/controllers/users_controller.rb

class UsersController < ApplicationController
  def index
    @users = User.all
  end
end
```

```ruby
# app/views/users/index.csv.decisive

csv @users, filename: "users-#{Time.zone.now.strftime("%Y_%m_%d")}.csv" do
  column :email
  column :name, label: "Full name"
  column :signed_up do |user|
    user.created_at.to_date
  end
end
```

Then visit /users.csv to get file named "users-2010_01_01.csv" with the following contents:

| Email             | Full name      | Signed up  |
| ----------------- | -------------- | ---------- |
| frodo@example.com | Frodo Baggins  | 2002-06-19 |
| sam@example.com   | Samwise Gamgee | 2008-10-13 |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/botandrose/decisive.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
