# Decisive

DSL for rendering and streaming CSVs in Rails apps

[![Build Status](https://travis-ci.org/botandrose/decisive.svg?branch=master)](https://travis-ci.org/botandrose/decisive)
[![Code Climate](https://codeclimate.com/github/botandrose/decisive/badges/gpa.svg)](https://codeclimate.com/github/botandrose/decisive)

## Usage

### Example usage:

```ruby
# app/controllers/users_controller.rb

class UsersController < ApplicationController
  include ActionController::Live # required to stream; decisive will fall back to rendering without it

  def index
    @users = User.all
  end
end
```

```ruby
# app/views/users/index.csv.decisive

csv @users, filename: "users-#{Time.zone.now.strftime("%Y_%m_%d")}.csv" do
  column "Email" # omitted accessor field gets inferred: user.email
  column "Full name", :name # explicit accessor field: user.name
  column "Signed up" do |user| # accepts a block for doing something special
    user.created_at.to_date
  end
end
```

Then visit /users.csv to stream a file named "users-2010_01_01.csv" with the following contents:

| Email             | Full name      | Signed up  |
| ----------------- | -------------- | ---------- |
| frodo@example.com | Frodo Baggins  | 2002-06-19 |
| sam@example.com   | Samwise Gamgee | 2008-10-13 |

### Non-streaming usage for non-deterministic headers:

Sometimes, we don't know exactly what the headers will be until we've iterated through every record.

For example, lets say that the Frodo record has a #faqs attribute of `{ "Riddles?" => "Yes" }`, while Sam's is `{ "Hero?" => "Frodo" }`.

In this case, you can pass `stream: false` to #csv, and the method will yield each record to the block:

```ruby
# app/views/users/index.csv.decisive

csv @users, filename: "users-#{Time.zone.now.strftime("%Y_%m_%d")}.csv", stream: false do |user|
  column "Email"
  column "Full name"

  user.faqs.favorite_questions_and_answers.each do |question, answer|
    column question, answer
  end

  column "Signed up", user.created_at.to_date # we have access to the user record directly
end
```

Visiting /users.csv will render a file named "users-2010_01_01.csv" with the following contents:

| Email             | Full name      | Riddles? | Hero? | Signed up  |
| ----------------- | -------------- | -------- | ----- | ---------- |
| frodo@example.com | Frodo Baggins  | Yes      |       | 2002-06-19 |
| sam@example.com   | Samwise Gamgee |          | Frodo | 2008-10-13 |

### Debugging

Errors in your decisive template will often be swallowed while streaming is enabled, resulting in only some of the csv being rendered, without any explanation. You can temporarily switch decisive into non-streaming mode to see these errors:

```ruby
# decisive template

csv @records, filename: "report.csv", stream: false do
  ...
end
```

```ruby
# controller

class ReportController < ApplicationController
  # include ActionController::Live

  ...
end
```

## Gotchas

Sometimes the streaming templates will hang in test mode. This could be because `action_controller/test_case` has been loaded, which monkeypatches AC::Live in a way that seems to breaks things. If you are running into this, try this workaround (cucumber example):

```ruby
# features/support/fix_ac_live.rb
# requiring cucumber/rails requires rails/test_help which requires action_controller/test_case which redefines AC::Live#new_controller_thread to be single threaded, which breaks our downloads
# set it back to original method definition

module ActionController
  module Live
    silence_redefinition_of_method :new_controller_thread
    def new_controller_thread # :nodoc:
      Thread.new {
        t2 = Thread.current
        t2.abort_on_exception = true
        yield
      }
    end
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/botandrose/decisive.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
