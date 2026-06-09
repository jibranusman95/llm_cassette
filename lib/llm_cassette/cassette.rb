# frozen_string_literal: true

require "yaml"
require "fileutils"
require "time"

module LlmCassette
  class Cassette
    attr_reader :name

    def initialize(name, record: nil)
      @name = name.to_s
      @record_mode = (record || LlmCassette.configuration.record).to_sym
      @interactions = []
      @replay_index = 0

      return if record?
      unless file_exists?
        raise CassetteNotFoundError, "Cassette '#{name}' not found at #{path}. " \
                                     "Re-run with record: :all to record it."
      end
      load!
    end

    def record?
      @record_mode == :all
    end

    def next_interaction
      interaction = @interactions[@replay_index]
      @replay_index += 1

      unless interaction
        raise NoMoreInteractionsError,
              "No more interactions in cassette '#{name}'. " \
              "Expected interaction ##{@replay_index} but cassette has #{@interactions.size}."
      end

      interaction
    end

    def record_interaction(interaction)
      @interactions << interaction
    end

    def eject!
      save! if record?
    end

    def size
      @interactions.size
    end

    private

    def path
      dir = LlmCassette.configuration.cassette_directory
      File.join(dir, "#{name}.yml")
    end

    def file_exists?
      File.exist?(path)
    end

    def load!
      data = YAML.safe_load_file(path, permitted_classes: [Symbol])
      @interactions = (data["interactions"] || []).map { |i| Interaction.from_hash(i) }
    end

    def save!
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, YAML.dump(to_h))
    end

    def to_h
      {
        "llm_cassette_version" => "1",
        "recorded_at" => Time.now.utc.iso8601,
        "interactions" => @interactions.map(&:to_h)
      }
    end
  end
end
