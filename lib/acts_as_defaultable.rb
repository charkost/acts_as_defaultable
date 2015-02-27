require 'active_support/concern'

module ActsAsDefaultable
  extend ActiveSupport::Concern

  included do
    def self.acts_as_defaultable(column = nil, options = {})

      after_save :set_unique_default

      column  ||= :default

      puts "acts_as_defaultable: Specify a column #{column} in #{self.to_s}" unless self.column_names.include?(column.to_s)

      if self.column_names.include?(column.to_s)
        positive_value =
          case self.columns_hash[column.to_s].type
          when :integer
            1
          when :boolean
            true
          when :string
            "'on'"
          end

        negative_value =
          case self.columns_hash[column.to_s].type
          when :integer
            0
          when :boolean
            false
          when :string
            "'off'"
          end
      end

      class_methods = %(
        def self.default_column
          "#{column.to_sym}"
        end

        def self.default_positive_value
          #{positive_value}
        end

        def self.default_negative_value
          #{negative_value}
        end

        def self.scope_of_default
          "#{options[:scope].to_s}"
        end
      )

      instance_methods = %(
        def foreign_key
          self.class.reflections[self.class.scope_of_default].foreign_key
        end
      )

      class_eval <<-EOF

        #{class_methods}
        #{instance_methods}

        def self.default
          if (defs = self.all_defaults).size == 1
            defs.first
          else
            nil
          end
        end

        def self.all_defaults
          where(self.default_column.to_sym => self.default_positive_value)
        end

        def set_unique_default
          if send(self.class.default_column) == self.class.default_positive_value
            self.class.all_defaults.reject do |x|
              if self.class.scope_of_default
                x == self || x.send(foreign_key) != self.send(foreign_key)
              else
                x == self
              end
            end.each do |obj|
              obj.update_attribute self.class.default_column, self.class.default_negative_value
            end
          end
        end

      EOF

    end
  end

end

ActiveRecord::Base.send :include, ActsAsDefaultable
