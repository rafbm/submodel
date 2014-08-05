# Submodel

Submodel maps ActiveRecord columns to ActiveModel models, so that [hstore](http://www.postgresql.org/docs/9.3/static/hstore.html) or [serialized](http://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Serialization/ClassMethods.html) hash columns can share validations and be augmented with some methods. This can greatly help cleanup your business logic.

## Usage

```ruby
# Gemfile
gem 'submodel'
```

Create a submodel with `ActiveModel::Model`. Here’s an example `Address` model using [Carmen](http://github.com/jim/carmen) to provide country and state validations.

```ruby
# app/submodels/address.rb

class Address
  include ActiveModel::Model

  COUNTRY_CODES  = Carmen::Country.all.map(&:code)
  CA_STATE_CODES = Carmen::Country.coded('CA').subregions.map(&:code)
  US_STATE_CODES = Carmen::Country.coded('US').subregions.map(&:code)

  attr_accessor :street_1, :street_2, :city, :state, :country, :postal_code

  validates_inclusion_of :country, in: COUNTRY_CODES
  validates_inclusion_of :state, in: CA_STATE_CODES, if: :canada?
  validates_inclusion_of :state, in: US_STATE_CODES, if: :united_states?

  def canada?
    country == 'CA'
  end

  def united_states?
    country == 'US'
  end
end
```

Use the `submodel` method to map your ActiveRecord columns to the submodel.

```ruby
# app/models/order.rb

class Order < ActiveRecord::Base
  submodel :billing_address, Address
end
```

Then, accessing `#billing_address` will return an instance created with `Address.new`. Similarly, passing a hash to `#billing_address=` will create a new instance with the hash as argument.

```ruby
order = Order.new
order.attributes # => { "id" => nil, "billing_address" => nil }

order.billing_address # => #<Address>
order.billing_address.blank? # => true

order.billing_address.street_1 = '123 Fake Street'
order.billing_address # => #<Address street_1="123 Fake Street">
order.billing_address.blank? # => false

order.billing_address = { country: 'CA', state: 'QC' }
order.billing_address # => #<Address state="QC" country="CA">
```

Note: While the getter creates an instance on demand, blank submodels are persisted as `NULL`.

## Comparison

When using `==`, your submodel columns will be compared based on the stringified hash of their instance variables. Blank variables are ignored.

```ruby
order = Order.new
order.billing_address # => #<Address>

order.billing_address == Address.new # => true
order.billing_address == {} # => true
order.billing_address == { street_1: '', street_2: '  ' } # => true
order.billing_address == { street_1: 'foo', street_2: 'bar' } # => false

order.billing_address.country = 'CA'
order.billing_address.state = 'QC'
order.billing_address == { 'country' => 'CA', :state => 'QC' } # => true
order.billing_address == Address.new(country: 'CA') # => false
```

## Extending submodels per-column

You can pass the `submodel` method a block to be executed at the class level. For instance, this adds an (unfortunate) validation to `shipping_address`, leaving `billing_address` as is.

```ruby
class Order < ActiveRecord::Base
  submodel :billing_address, Address
  submodel :shipping_address, Address do
    validates :country, inclusion: { in: %w[US CA] }
  end
end
```

## This gem seems overkill.

You might think “Why not just override the getter and setter?” In my experience, getting this *right* is always more complex. If you want proper behavior (validation, comparison, FormBuilder support, persistence) you basically have to repeat [this code](lib/submodel/active_record.rb) for every column.

---

© 2014 [Rafaël Blais Masson](http://rafbm.com). Submodel is released under the MIT license.
