
require 'thread'
require 'cond/cond_inner/symbol_generator'

module Cond
  module CondInner
    #
    # Thread-local variable.
    #
    class ThreadLocal
      include SymbolGenerator

      #
      # If +value+ is called before +value=+ then the result of
      # &default is used.
      #
      # &default normally creates a new object, otherwise the returned
      # object will be shared across threads.
      #
      def initialize(prefix = nil, &default)
        @name = gensym(prefix)
        @accessed = gensym(prefix)
        @default = default
        SymbolGenerator.track(self, [@name, @accessed])
      end

      #
      # Reset to just-initialized state for all threads.
      #
      def clear(&default)
        @default = default
        Thread.exclusive {
          Thread.list.each { |thread|
            thread[@accessed] = nil
            thread[@name] = nil
          }
        }
      end
      
      def value
        unless Thread.current[@accessed]
          if @default
            Thread.current[@name] = @default.call
          end
          Thread.current[@accessed] = true
        end
        Thread.current[@name]
      end
      
      def value=(value)
        Thread.current[@accessed] = true
        Thread.current[@name] = value
      end

      class << self
        def accessor_module(name, subclass = self, &block)
          var = subclass.new(name, &block)
          Module.new {
            define_method(name) {
              var.value
            }
            define_method("#{name}=") { |value|
              var.value = value
            }
          }
        end

        def wrap_methods(names)
          Class.new(ThreadLocal) {
            names.each { |name|
              # TODO: jettison 1.8.6, remove eval and use |&block|
              eval %{
                def #{name}(*args, &block)
                  value.send(:'#{name}', *args, &block)
                end
              }
            }
          }
        end
        
        def wrap_methods_of(klass, opts = {})
          include_super = opts[:include_super] || true
          names = klass.instance_methods(include_super).reject { |name|
            name =~ %r!\A__! or name.to_sym == :object_id
          }
          wrap_methods(names)
        end

        def wrap_new(klass, opts = {}, &block)
          create = block || lambda { klass.new }
          wrap_methods_of(klass, opts).new(&create)
        end
      end
    end
  end
end
