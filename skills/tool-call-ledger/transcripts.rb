# frozen_string_literal: true

require 'uri'

module Ledger
  # Read native records, never evaluate commands or orchestration source.
  # Codex can record the same call as both a request and a completed item;
  # completed CommandExecution items take precedence within each file.
  class Transcripts
    SHELLS = %w[sh bash zsh dash ksh fish].freeze
    DIRECT = %w[exec_command shell_command shell].freeze

    def initialize(path)
      @path = path
      @session = File.basename(path, '.jsonl')
      @cwd = ''
      @requests = {}
      @executions = {}
      @direct = {}
      @claude = []
      @codex = false
      @orchestration = false
    end

    def read
      File.foreach(@path).with_index do |line, index|
        accept(JSON.parse(line), index)
      rescue JSON::ParserError
        # A live transcript may end with an incomplete JSON line.
        next
      end
      codex = @executions.empty? ? @direct.values : @executions.values
      report(codex) if @codex
      @claude + codex
    end

    private

    def accept(row, index)
      return unless row.is_a?(Hash)
      return claude(row) if row['type'] == 'assistant'

      payload = row['payload']
      return unless payload.is_a?(Hash)

      case row['type']
      when 'session_meta'
        @codex = true
        @session = payload['id'] || @session
        @cwd = payload['cwd'] || @cwd
      when 'turn_context'
        @cwd = payload['cwd'] || @cwd
      when 'event_msg'
        execution(row, payload, index) if payload['type'] == 'item_completed'
      when 'response_item'
        request(row, payload, index)
      end
    end

    # Every Bash tool_use block is one record, exactly as before Codex
    # support; Claude records are not deduplicated.
    def claude(row)
      blocks = row.dig('message', 'content')
      return unless blocks.is_a?(Array)

      blocks.each do |block|
        next unless block.is_a?(Hash) && block['type'] == 'tool_use' && block['name'] == 'Bash'

        command = block.dig('input', 'command')
        next unless command.is_a?(String) && !command.empty?

        @claude << Record.new(row['timestamp'].to_s, row['cwd'].to_s,
                              row['sessionId'] || @session, command, 'claude')
      end
    end

    def execution(row, payload, index)
      item = payload['item']
      return unless item.is_a?(Hash) && item['type'] == 'CommandExecution'

      @codex = true
      command = shell_text(item['command'])
      return unless command

      key = item['id'] || index
      @executions[key] = record(row, item['cwd'], command)
    end

    def request(row, payload, index)
      return unless %w[function_call custom_tool_call].include?(payload['type'])

      @codex = true
      key = payload['call_id'] || payload['id'] || index
      @requests[key] = true
      @orchestration ||= payload['type'] == 'custom_tool_call' && payload['name'] == 'exec'
      return unless DIRECT.include?(payload['name'].to_s.split('.').last)

      args = payload['arguments']
      args = JSON.parse(args) if args.is_a?(String)
      return unless args.is_a?(Hash)

      command = shell_text(args['cmd'] || args['command'])
      @direct[key] = record(row, args['workdir'] || args['cwd'], command) if command
    rescue JSON::ParserError
      nil
    end

    def shell_text(value)
      return value if value.is_a?(String) && !value.empty?
      return unless value.is_a?(Array) && !value.empty? && value.all? { |part| part.is_a?(String) }

      if value.length == 3 && SHELLS.include?(File.basename(value.first)) && value[1].match?(/\A-[a-z]*c[a-z]*\z/)
        value.last
      else
        Shellwords.join(value)
      end
    end

    def record(row, cwd, command)
      cwd = @cwd unless cwd.is_a?(String)
      cwd = URI::DEFAULT_PARSER.unescape(cwd.delete_prefix('file://')) if cwd.start_with?('file://')
      Record.new(row['timestamp'].to_s, cwd, @session, command, 'codex')
    end

    def report(records)
      basis = @executions.empty? ? 'shell requests (completion unknown)' : 'completed shell executions (including failures)'
      warn "tool-call-ledger: Codex #{@session}: #{@requests.size} recorded tool requests; #{records.size} #{basis}"
      if @orchestration && @executions.empty?
        warn 'tool-call-ledger: orchestration has no completed command records; embedded JavaScript is not evaluated or counted as shell execution'
      end
    end
  end
end
