module Submodel
  def self.values(object)
    object.instance_values.select { |key, value|
      # This filters out ActiveModel::Validation’s @error variable since it has no setter
      object.respond_to?("#{key}=") && value.present?
    }
  end

  module ActiveRecord
    extend ActiveSupport::Concern

    module ClassMethods
      def submodel(attr, klass, validation_options = {}, &block)
        column = columns_hash[attr.to_s]

        augmented_klass = Class.new(klass) do
          define_singleton_method :name do
            klass.name
          end

          define_method :inspect do
            attrs = Submodel.values(self).map { |k,v| "#{k}=#{v.inspect}" }.join(' ').presence
            string = [klass.name, attrs].compact.join(' ')
            "#<#{string}>"
          end
          alias_method :to_s, :inspect

          define_method :blank? do
            Submodel.values(self).blank?
          end

          define_method :== do |other|
            hash = Submodel.values(self)

            if other.is_a? klass
              hash == Submodel.values(other)
            elsif other.is_a? Hash
              hash == other.stringify_keys
            else
              hash == other
            end
          end
        end

        if block_given?
          augmented_klass.class_eval &block
        end

        serialize attr, Module.new {
          define_singleton_method :load do |value|
            if value.is_a? String
              case column.type
              when :hstore
                value = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn.string_to_hstore(value)
              when :json
                value = JSON.parse(value)
              else
                value = YAML.load(value)
              end
            end
            value.present? ? augmented_klass.new(value) : nil
          end

          define_singleton_method :dump do |object|
            if hash = Submodel.values(object).presence
              case column.type
              when :hstore, :json then hash
              else YAML.dump(hash)
              end
            else
              nil
            end
          end
        }

        # Include as module so we can override accessors and use `super`
        include Module.new {
          define_method attr do
            self[attr] ||= augmented_klass.new
          end

          define_method :"#{attr}=" do |value|
            if value.nil?
              self[attr] = nil
            elsif value.is_a? klass
              self[attr] = value.dup
            else
              self[attr] = augmented_klass.new(value)
            end
          end
          alias_method :"#{attr}_attributes=", :"#{attr}="
        }

        validates_each(attr, validation_options) do |record, attribute, object|
          if object.try(:invalid?)
            record.errors.add(attribute, object.errors.full_messages.to_sentence.downcase)
          end
        end
      end
    end
  end
end
