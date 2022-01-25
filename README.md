# PGTrunk

Empower PostgreSQL migrations in Rails app

<a href="https://evilmartians.com/">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Sponsored by Evil Martians" width="236" height="54"></a>

[![Gem Version][gem-badger]][gem]
[![Build Status][build-badger]][build]

PGTrunk adds methods to `ActiveRecord::Migration` to create and manage
various PostgreSQL objects (like views, functions, triggers, statistics, types etc.)
in Rails.

This gem is greatly influenced by the [Scenic], [F(x)] and [ActiveRecord::PostgtresEnum] projects
but takes some steps further.

In addition to support of different objects, we are solving a problem of interdependency between them.
For example, you can create a table, then a function using its type as an argument,
then check constraint and index using the function:

```ruby
create_table "users" do |t|
  t.text "first_name"
  t.text "last_name"
end

# depends on the `users` table
create_function "full_name(u users) text" do |f|
  f.volatility :immutable
  f.strict true
  f.parallel :safe
  f.body <<~SQL.strip
    string_trim(
      SELECT COALESCE(u.first_name, '') + '.' + COALESCE(u.second_name, ''),
      '.'
    )
  SQL
end

# both objects below depend on the `users` and `full_name(users)`
# so they couldn't be placed inside the `create_table` definition in the schema.

create_index "users", "full_name(users.*)", unique: true

# users.full_name is the PostgreSQL alternative syntax for the `full_name(users.*)`
create_check_constraint "users", "length(users.full_name) > 0", name: "full_name_present"
```

Notice, that we had to separate definitions of indexes and check constraints from tables,
because there can be other objects (like functions or types) squeezing between them.

Another difference from aforementioned gems is that we explicitly register
all objects created by migrations in the special table (`pg_trunk`).
This let us distinct objects created by "regular" migration from temporary ones
added manually and exclude the latter from the schema. We bind any object
to a particular version of migration which added it. That's how only those
objects that belong to the current branch are dumped into the `schema.rb`.

As of today we support creation, modification and dropping the following objects:

- tables
- indexes
- foreign keys (including multi-column ones)
- check constraints
- views
- materialized views
- functions
- procedures
- triggers
- custom statistics
- enumerable types
- composite types
- domains types
- rules
- sequences

For `tables` and `indexes` we reuse the ActiveRecord's native methods.
For `check constraints` and `foreign keys` we support both the native definitions inside the table
and standalone methods (like `create_foreign_key`) with additional features.
The other methods are implemented from scratch.

In the future other objects like aggregate functions, range types, operators, collations, and more
will be supported.

From now and on we support all versions of PostgreSQL since v10.

The gem is targeted to support PostgreSQL-specific features, that's why we won't provide adapters to other databases like [Scenic] does.

## Documentation

The gem provides a lot of additional methods to create, rename, change a drop various objects.
You can find the necessary details [here](https://rubydoc.info/gems/pg_trunk/ActiveRecord/Migration).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pg_trunk'
```

And then execute:

```shell
$ bundle install
```

Or install it yourself as:

```shell
$ gem install pg_trunk
```

Add the line somewhere in your ruby code:

```ruby
require "pg_trunk"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at `https://github.com/nepalez/pg_trunk`.

## License

The gem is available as open source under the terms of the [MIT License].

[build-badger]: https://github.com/nepalez/pg_trunk/workflows/CI/badge.svg
[build]: https://github.com/nepalez/pg_trunk/actions?query=workflow%3ACI+branch%3Amaster
[gem-badger]: https://img.shields.io/gem/v/pg_trunk.svg?style=flat
[gem]: https://rubygems.org/gems/pg_trunk
[MIT License]: https://opensource.org/licenses/MIT
[Scenic]: https://github.com/scenic-views/scenic
[F(x)]: https://github.com/teoljungberg/fx
[ActiveRecord::PostgtresEnum]: https://github.com/bibendi/activerecord-postgres_enum
[wiki]: https://github.com/nepalez/pg_trunk/wiki
