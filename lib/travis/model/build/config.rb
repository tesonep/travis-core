require 'travis/model/build/config/env'
require 'travis/model/build/config/features'
require 'travis/model/build/config/language'
require 'travis/model/build/config/matrix'
require 'travis/model/build/config/obfuscate'
require 'travis/model/build/config/os'
require 'travis/model/build/config/yaml'

class Build
  class Config
    NORMALIZERS = [Features, Yaml, Env, Language]

    DEFAULT_LANG = 'ruby'

    ENV_KEYS = [
      :compiler,
      :crystal,
      :csharp,
      :d,
      :dart,
      :elixir,
      :env,
      :fsharp,
      :gemfile,
      :ghc,
      :go,
      :haxe,
      :jdk,
      :julia,
      :mono,
      :node_js,
      :otp_release,
      :perl,
      :perl6,
      :php,
      :python,
      :ruby,
      :rust,
      :rvm,
      :scala,
      :smalltalk,
      :visualbasic,
      :xcode_scheme,
      :xcode_sdk
    ]

    EXPANSION_KEYS_FEATURE = [:os]

    EXPANSION_KEYS_LANGUAGE = {
      'c'           => [:compiler],
      'c++'         => [:compiler],
      'clojure'     => [:lein, :jdk],
      'cpp'         => [:compiler],
      'crystal'     => [:crystal],
      'csharp'      => [:csharp, :mono],
      'd'           => [:d],
      'dart'        => [:dart],
      'elixir'      => [:elixir, :otp_release],
      'erlang'      => [:otp_release],
      'fsharp'      => [:fsharp, :mono],
      'go'          => [:go],
      'groovy'      => [:jdk],
      'haskell'     => [:ghc],
      'haxe'        => [:haxe],
      'java'        => [:jdk],
      'julia'       => [:julia],
      'node_js'     => [:node_js],
      'objective-c' => [:rvm, :gemfile, :xcode_sdk, :xcode_scheme],
      'perl'        => [:perl],
      'perl6'       => [:perl6],
      'php'         => [:php],
      'python'      => [:python],
      'ruby'        => [:rvm, :gemfile, :jdk, :ruby],
      'rust'        => [:rust],
      'scala'       => [:scala, :jdk],
      'smalltalk'   => [:smalltalk],
      'visualbasic' => [:visualbasic, :mono]
    }

    EXPANSION_KEYS_UNIVERSAL = [:env, :branch]

    def self.matrix_keys_for(config, options = {})
      keys = matrix_keys(config, options)
      keys & config.keys.map(&:to_sym)
    end

    def self.matrix_keys(config, options = {})
      lang = Array(config.symbolize_keys[:language]).first
      keys = ENV_KEYS
      keys &= EXPANSION_KEYS_LANGUAGE.fetch(lang, EXPANSION_KEYS_LANGUAGE[DEFAULT_LANG])
      keys << :os if options[:multi_os]
      keys += [:dist, :group] if options[:dist_group_expansion]
      keys | EXPANSION_KEYS_UNIVERSAL
    end

    attr_reader :config, :options

    def initialize(config, options = {})
      @config = (config || {}).deep_symbolize_keys
      @options = options
    end

    def normalize
      normalizers = options[:multi_os] ? NORMALIZERS : NORMALIZERS + [OS]
      normalizers.inject(config) do |config, normalizer|
        normalizer.new(config, options).run
      end
    end

    def obfuscate
      Obfuscate.new(config, options).run
    end
  end
end
