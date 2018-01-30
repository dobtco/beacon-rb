module DispatchConfiguration
  class << self
    def theme_path
      Rails.root.join("themes/#{theme}")
    end

    def method_missing(name)
      ENV[name.to_s.upcase] ||
      read_configuration[name.to_s.upcase]
    end

    private

    def read_configuration
      @configuration ||= YAML.safe_load(File.read(config_file))
    end

    def config_file
      if File.exist?(Rails.root.join('config.yml'))
        Rails.root.join('config.yml')
      else
        # For development modes and the like, just use the defaults in the
        # example file
        Rails.root.join('config.yml.example')
      end
    end
  end
end
