require 'submodel'

# Suppress annoying deprecation notice
I18n.enforce_available_locales = false

class Address
  include ActiveModel::Model

  COUNTRY_CODES  = Carmen::Country.all.map(&:code)
  US_STATE_CODES = Carmen::Country.coded('US').subregions.map(&:code)
  CA_STATE_CODES = Carmen::Country.coded('CA').subregions.map(&:code)

  attr_accessor :street_1, :street_2, :city, :state, :country, :postal_code

  validates :country, inclusion: { in: COUNTRY_CODES }

  with_options if: -> { country == 'US' } do |o|
    o.validates :state, inclusion: { in: US_STATE_CODES }
    o.validates :postal_code, format: /\d{5}/
  end

  with_options if: -> { country == 'CA' } do |o|
    o.validates :state, inclusion: { in: CA_STATE_CODES }
    o.validates :postal_code, format: /[a-z]\d[a-z]\W*\d[a-z]\d/i
  end
end

shared_examples Submodel do
  before do
    Object.send(:remove_const, 'Order') if Object.const_defined? 'Order'

    class Order < ActiveRecord::Base
      submodel :billing_address, Address
      submodel :shipping_address, Address, allow_blank: true do
        validates :country, inclusion: { in: %w[US CA ME] }, allow_blank: true
      end

      # This tests that accessors are included as a module
      def billing_address=(value)
        super
      end
      def shipping_address
        super
      end
    end
  end

  let(:valid_address_hash) { { 'country' => 'CA', :state => 'QC', 'postal_code' => 'G1K 3J3' } }
  let(:valid_address) { Address.new(valid_address_hash) }
  let(:order) { Order.new }

  it 'class name is the same' do
    expect(order.billing_address.class.name).to eq 'Address'
    expect(order.shipping_address.class.name).to eq 'Address'
  end

  context 'when model attribute is nil' do
    it 'leaves attribute as nil' do
      expect(order.attributes).to eq({
        'id' => nil, 'billing_address' => nil, 'shipping_address' => nil
      })
      expect(order[:billing_address]).to eq nil
      expect(order[:shipping_address]).to eq nil
    end

    describe 'getter' do
      it 'sets attribute to blank submodel instance' do
        expect(order.billing_address).to be_a Address
        expect(order.billing_address.blank?).to eq true
      end
    end

    describe 'setter' do
      it 'sets attribute to object with passed value' do
        order.billing_address = { street_1: '123 Fake Street' }
        expect(order[:billing_address]).to be_a Address
        expect(order[:billing_address].street_1).to eq '123 Fake Street'
      end
    end

    describe '== comparison' do
      it 'returns true when passed empty hash' do
        expect(order.billing_address == {}).to eq true
      end

      it 'returns false when passed non-empty hash' do
        expect(order.billing_address == { foo: 'bar' }).to eq false
      end
    end

    [:inspect, :to_s].each do |meth|
      describe "##{meth}" do
        it 'outputs the right class name' do
          expect(order.billing_address.public_send(meth)).to eq '#<Address>'
        end
      end
    end
  end

  context 'when model attribute has value' do
    let(:order) { Order.new(billing_address: { street_1: '123 Foo Street' }) }
    let(:equivalent_address) { Address.new(street_1: '123 Foo Street', street_2: '') }
    let(:different_address) { Address.new(street_1: '123 Bar Street') }

    describe '== comparison' do
      it 'returns true when passed equivalent object' do
        expect(order.billing_address == equivalent_address).to eq true
      end

      it 'returns false when passed different object' do
        expect(order.billing_address == different_address).to eq false
      end

      it 'returns false when passed different hash' do
        expect(order.billing_address == { 'street_1' => 'blah blah blah' }).to eq false
      end

      it 'returns true when passed equivalent hash with string keys' do
        expect(order.billing_address == { 'street_1' => '123 Foo Street' }).to eq true
      end

      it 'returns true when passed equivalent hash with symbol keys' do
        expect(order.billing_address == { street_1: '123 Foo Street' }).to eq true
      end

      it 'returns false when passed irrelevant object' do
        expect(order.billing_address == 1).to eq false
      end
    end

    describe 'setter' do
      it 'dups object when passed other object' do
        order.billing_address = different_address
        expect(order.billing_address.street_1).to eq '123 Bar Street'

        order.billing_address.street_1 = 'blah blah blah'
        expect(order.billing_address.street_1).to eq 'blah blah blah'
        expect(different_address.street_1).to eq '123 Bar Street'
      end

      it 'sets attribute to nil when passed nil' do
        order.billing_address = nil
        expect(order[:billing_address]).to eq nil
      end
    end

    [:inspect, :to_s].each do |meth|
      describe "##{meth}" do
        it 'outputs the right class name and variables' do
          order.billing_address.street_2 = 'apt. 2'
          expect(order.billing_address.public_send(meth)).to eq(
            '#<Address street_1="123 Foo Street" street_2="apt. 2">'
          )
        end
      end
    end
  end

  describe 'persistence' do
    context 'passing empty hash to setter' do
      it 'persists NULL' do
        order = Order.create!(
          billing_address: valid_address,
          shipping_address: {},
        )
        expect(raw_select(:orders, :shipping_address, id: order.id)).to eq nil

        order = Order.first
        expect(order.billing_address).to eq valid_address
        expect(order.shipping_address).to eq({})
      end
    end

    context 'passing hash with blank values to setter' do
      it 'persists NULL' do
        order = Order.create!(
          billing_address: valid_address,
          shipping_address: { street_1: '', city: '   ' },
        )
        expect(raw_select(:orders, :shipping_address, id: order.id)).to eq nil

        order = Order.first
        expect(order.billing_address).to eq valid_address
        expect(order.shipping_address).to eq({})
      end
    end

    context 'passing hash with non-blank values to setter' do |example|
      it 'persists hash' do
        order = Order.create!(
          billing_address: valid_address,
          shipping_address: { street_1: '123 Fake Street', city: 'Springfield', country: 'ME' },
        )

        case example.metadata[:billing_address_type]
        when :hstore
          billing_string = '"state"=>"QC", "country"=>"CA", "postal_code"=>"G1K 3J3"'
        when :json
          billing_string = '{"country":"CA","state":"QC","postal_code":"G1K 3J3"}'
        else
          billing_string = "---\ncountry: CA\nstate: QC\npostal_code: G1K 3J3\n"
        end
        expect(raw_select(:orders, :billing_address, id: order.id)).to eq billing_string

        case example.metadata[:shipping_address_type]
        when :hstore
          shipping_string = '"city"=>"Springfield", "country"=>"ME", "street_1"=>"123 Fake Street"'
        when :json
          shipping_string = '{"street_1":"123 Fake Street","city":"Springfield","country":"ME"}'
        else
          shipping_string = "---\nstreet_1: 123 Fake Street\ncity: Springfield\ncountry: ME\n"
        end
        expect(raw_select(:orders, :shipping_address, id: order.id)).to eq shipping_string

        order = Order.first
        expect(order.billing_address).to eq valid_address
        expect(order.shipping_address).to eq({
          street_1: '123 Fake Street', city: 'Springfield', country: 'ME'
        })
      end
    end

    it 'doesn’t persist ActiveModel::Validation’s @error variable' do |example|
      order = Order.new(billing_address: { state: 'QC', country: 'US' })
      order.valid?
      order.save! validate: false

      case example.metadata[:billing_address_type]
      when :hstore
        billing_string = '"state"=>"QC", "country"=>"US"'
      when :json
        billing_string = '{"state":"QC","country":"US"}'
      else
        billing_string = "---\nstate: QC\ncountry: US\n"
      end
      expect(raw_select(:orders, :billing_address, id: order.id)).to eq billing_string
    end
  end

  context 'when validating presence of submodel' do
    let(:order) { Order.new(billing_address: { state: ' ', postal_code: '' }) }

    it 'doesn’t accept blank object' do
      expect(order.valid?).to eq false
      expect(order.errors.keys).to include :billing_address
    end
  end

  context 'when not validating presence of submodel' do
    let(:order) {
      Order.new(billing_address: valid_address_hash, shipping_address: { state: ' ', postal_code: '' })
    }

    it 'accepts blank object' do
      expect(order.valid?).to eq true
    end

    it 'doesn’t accept invalid object' do
      order.shipping_address = Address.new(country: 'CA', state: 'FOO')
      expect(order.valid?).to eq false
      expect(order.errors.keys).to include :shipping_address
    end
  end

  context 'when extending one submodel column' do
    let(:order) {
      Order.new(
        billing_address:  { country: 'NL' },
        shipping_address: { country: 'NL' },
      )
    }

    it 'affects only the said column' do
      expect(order.invalid?).to eq true
      expect(order.errors.keys).to eq [:shipping_address]
    end
  end

  describe 'submodel validation error message' do
    it 'makes a sentence with all submodel errors' do
      order = Order.new(
        billing_address: { country: 'US', state: 'QC', postal_code: 'H0H 0H0' },
      )
      expect(order.valid?).to eq false
      expect(order.errors.full_messages).to eq [
        'Billing address state is not included in the list and postal code is invalid'
      ]
    end
  end

  describe 'XXX_attributes= methods' do
    it 'works' do
      order = Order.new(billing_address_attributes: valid_address_hash)
      expect(order.billing_address).to eq valid_address
    end
  end

  describe 'attributes_before_type_cast' do
    it 'does not break' do
      order = Order.create!(billing_address: valid_address_hash, shipping_address: valid_address_hash)
      expect(Order.last.attributes_before_type_cast.keys).to eq ['id', 'billing_address', 'shipping_address']
    end
  end
end

describe 'PostgreSQL', billing_address_type: :hstore, shipping_address_type: :json do
  before do
    ActiveRecord::Base.establish_connection(
      adapter: 'postgresql', username: `whoami`.chomp, database: 'submodel_spec')

    run_migration do
      enable_extension :hstore

      create_table :orders, force: true do |t|
        t.hstore :billing_address
        t.json :shipping_address
      end
    end
  end

  it_behaves_like Submodel
end

describe 'SQLite', billing_address_type: :text, shipping_address_type: :text do
  before do
    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3', database: 'tmp/submodel.sqlite3')

    run_migration do
      create_table :orders, force: true do |t|
        t.text :billing_address
        t.text :shipping_address
      end
    end
  end

  it_behaves_like Submodel
end

describe 'MySQL', billing_address_type: :text, shipping_address_type: :text do
  before do
    ActiveRecord::Base.establish_connection(
      adapter: 'mysql2', username: 'root', database: 'submodel_spec')

    run_migration do
      create_table :orders, force: true do |t|
        t.text :billing_address
        t.text :shipping_address
      end
    end
  end

  it_behaves_like Submodel
end
