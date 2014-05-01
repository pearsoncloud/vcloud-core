require 'erb'
require 'ostruct'

module Vcloud
  module Core
    class ConfigLoader

      def load_config(config_file, schema = nil, vars_file = nil)
        if vars_file
          vars = OpenStruct.new(YAML::load_file(vars_file))
          template = ERB.new(File.read(config_file))
          rendered_config = template.result(vars.instance_eval { binding })
          input_config = YAML::load(rendered_config)
        else
          input_config = YAML::load_file(config_file)
        end

        # There is no way in YAML or Ruby to symbolize keys in a hash
        json_string = JSON.generate(input_config)
        config = JSON.parse(json_string, :symbolize_names => true)

        if schema
          validation = Core::ConfigValidator.validate(:base, config, schema)
          unless validation.valid?
            validation.errors.each do |error|
              Vcloud::Core.logger.fatal(error)
            end
            raise("Supplied configuration does not match supplied schema")
          end
        end

        config
      end

    end
  end
end
