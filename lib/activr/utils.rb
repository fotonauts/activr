module Activr

  # Utilities methods
  class Utils

    class << self

      # Returns kind for given class
      #
      # @api private
      #
      # @param klass [Class] Class
      # @param suffix [String] Expected suffix
      # @return [String] Kind
      def kind_for_class(klass, suffix = nil)
        class_name = klass.to_s.split('::').last.underscore
        if suffix && (match_data = class_name.match(/(.+)_#{suffix}$/))
          match_data[1]
        else
          class_name
        end
      end

      # Returns class for given kind
      #
      # @api private
      #
      # @param kind [String] Kind
      # @param suffix [String] Suffix
      # @return [Class] Class
      def class_for_kind(kind, suffix = nil)
        str = suffix ? "#{kind}_#{suffix}" : kind
        str.camelize.constantize
      end


      #
      # Mustache rendering
      #

      # Get a compiled mustache template
      #
      # @api private
      #
      # @param tpl [String] Template
      # @return [String] Compiled template
      def compiled_mustache_template(tpl)
        @compiled_mustache_templates ||= {}
        @compiled_mustache_templates[tpl] ||= begin
          view = Mustache.new
          view.raise_on_context_miss = true
          view.template = tpl # will compile and store template once for all
          view
        end
      end

      # Render a mustache template
      #
      # @api private
      #
      # @param text     [String] Template to render
      # @param bindings [Hash] Template bindings
      # @return [String] Rendered template
      def render_mustache(text, bindings)
        tpl = self.compiled_mustache_template(text)
        tpl.raise_on_context_miss = true
        tpl.render(bindings)
      end

    end # class << self

  end # class Utils

end # module Activr
