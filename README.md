# Decisive

DSL for rendering CSVs in Rails apps

[![Build Status](https://travis-ci.org/botandrose/decisive.svg?branch=master)](https://travis-ci.org/botandrose/decisive)
[![Code Climate](https://codeclimate.com/github/botandrose/decisive/badges/gpa.svg)](https://codeclimate.com/github/botandrose/decisive)

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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/botandrose/decisive.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
