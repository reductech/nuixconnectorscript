require 'simplecov'
SimpleCov.start do
  add_filter '/vendor/'
end
require 'simplecov-cobertura'
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

require 'nuixconnectorscript'
include NuixConnectorScript

################################################################################

describe 'log' do

  it 'logs a message with info severity by default' do
    expected = Regexp.escape('{"log":{"severity":"info","message":"message!","time":"')
                     .concat('.+')
                     .concat(Regexp.escape('","stackTrace":""}}'))
    expect do
      log "message!"
    end.to output(/^#{expected}\r?\n$/).to_stdout
  end

  it 'logs a message with specified severity' do
    expected = Regexp.escape('{"log":{"severity":"error","message":"error!","time":"')
                     .concat('.+')
                     .concat(Regexp.escape('","stackTrace":""}}'))
    expect do
      log("error!", severity: :error)
    end.to output(/^#{expected}\r?\n$/).to_stdout
  end

  it 'logs custom time and stacktrace if set' do
    expected = Regexp.escape('{"log":{"severity":"warn","message":"warning!","time":"time","stackTrace":"stack"}}')
    expect do
      log("warning!", severity: :warn, timestamp: 'time', stack: 'stack')
    end.to output(/^#{expected}\r?\n$/).to_stdout
  end

  it 'does not log if severity is less than LOG_SEVERITY' do
    $VERBOSE = nil
    NuixConnectorScript::LOG_SEVERITY = :info
    $VERBOSE = false
    expect do
      log("nothing please", severity: :debug)
    end.to_not output.to_stdout
  end

end

################################################################################

describe 'return_result' do
  it 'outputs result json to stdout' do
    expected = Regexp.escape('{"result":{"data":"message!"}}')
    expect do
      return_result "message!"
    end.to output(/^#{expected}\r?\n$/).to_stdout
  end
end

################################################################################

describe 'write_error' do

  context 'logging' do

    before(:all) do
      @orig_err = $stderr
      $stderr = StringIO.new
    end

    after(:all) do
      $stderr = @orig_err
    end

    it 'logs message with error severity by default' do
      expected = Regexp.escape('{"log":{"severity":"error","message":"error!","time":"')
                  .concat('.+')
                  .concat(Regexp.escape('","stackTrace":""}}'))
      expect do
        write_error "error!"
      end.to output(/^#{expected}\r?\n$/).to_stdout
    end

    it 'logs custom time and stacktrace if set' do
      expected = Regexp.escape('{"log":{"severity":"error","message":"error!","time":"time","stackTrace":"stack"}}')
      expect do
        write_error("error!", timestamp: 'time', stack: 'stack')
      end.to output(/^#{expected}\r?\n$/).to_stdout
    end

  end

  context 'stderr' do

    before(:all) do
      @orig_out = $stdout
      $stdout = StringIO.new
    end

    after(:all) do
      $stdout = @orig_out
    end

    it 'writes message to STDERR by default' do
      expected = Regexp.escape('{"error":{"message":"error!","time":"')
                  .concat('.+')
                  .concat(Regexp.escape('","location":"","stackTrace":""}}'))
      expect do
        write_error "error!"
      end.to output(/^#{expected}\r?\n$/).to_stderr
    end

    it 'writes custom time, location and stacktrace to stderr if set' do
      expected = Regexp.escape('{"error":{"message":"error!","time":"time","location":"location","stackTrace":"stack"}}')
      expect do
        write_error("error!", timestamp: 'time', location: 'location', stack: 'stack')
      end.to output(/^#{expected}\r?\n$/).to_stderr
    end

  end

  context 'terminating' do

    before(:all) do
      @orig_err = $stderr
      @orig_out = $stdout
      $stderr = StringIO.new
      $stdout = StringIO.new
    end

    after(:all) do
      $stderr = @orig_err
      $stdout = @orig_out
    end

    it 'exits when the error is terminating' do
      expect do
        write_error("terminating!", terminating: true)
      end.to raise_error(SystemExit)
    end

  end
  
end

################################################################################

describe 'return_entity' do
  it 'outputs entity json to stdout' do
    expected = Regexp.escape('{"entity":{"prop1":"value","prop2":1}}')
    expect do
      return_entity({ prop1: 'value', prop2: 1 })
    end.to output(/^#{expected}\r?\n$/).to_stdout
  end
end

################################################################################

def run_listen(send = [])
  thread = Thread.new do
    listen
  end
  sleep(0.1)
  send.each { |msg| $stdout.puts msg }
  thread.join
end

describe 'listen' do

  DONE_JSON = '{"cmd":"done"}'
  DATA_JSON = '{"cmd":"datastream"}'

  LOG_START = '\{"log":\{"severity":"info","message":"Starting","time":".+","stackTrace":""\}\}\r?\n'
  LOG_END   = '\{"log":\{"severity":"info","message":"Finished","time":".+","stackTrace":""\}\}\r?\n'

  #RSpec::Matchers.define_negated_matcher :not_output, :output

  # it 'returns when END_CMD is received' do
  #   $VERBOSE = nil
  #   NuixConnectorScript::END_CMD = 'end'
  #   $VERBOSE = false
  #   allow($stdin).to receive(:gets) { '{"cmd":"end"}' }
  #   th = Thread.new {listen}
  #   result = nil
  #   expect($stdout).to receive(:puts).twice
  #   expect{result = th.join(1)}.not_to raise_error
  #   expect(result).to_not be_nil
  # end

  it 'logs start and end message' do
    allow($stdin).to receive(:gets) { DONE_JSON }
    expected = LOG_START + LOG_END
    expect{run_listen}.to output(/^#{expected}$/).to_stdout
  end

  it 'runs function and returns a result message' do
    func = "def get_result\\n  return 'hello'\\nend"
    allow($stdin).to receive(:gets).twice.and_return(
      "{\"cmd\":\"get_result\",\"def\":\"#{func}\"}",
      DONE_JSON
    )
    expected = LOG_START + Regexp.escape('{"result":{"data":"hello"}}') + '\r?\n' + LOG_END
    expect{run_listen}.to output(/^#{expected}$/).to_stdout
  end

  it 'uses stored def to run same function' do
    func = "def get_result\\n  return 'hi'\\nend"
    allow($stdin).to receive(:gets).exactly(3).and_return(
      "{\"cmd\":\"get_result\",\"def\":\"#{func}\"}",
      "{\"cmd\":\"get_result\"}",
      DONE_JSON
    )
    expected = LOG_START +
                 Regexp.escape('{"result":{"data":"hi"}}') +
                 '\r?\n' +
                 Regexp.escape('{"result":{"data":"hi"}}') +
                 '\r?\n' +
                 LOG_END
    expect{run_listen}.to output(/^#{expected}$/).to_stdout
  end

  it 'replaces a function if a new def is provided' do
    allow($stdin).to receive(:gets).exactly(3).and_return(
      "{\"cmd\":\"get_result\",\"def\":\"def get_result\\n  return 'hi'\\nend\"}",
      "{\"cmd\":\"get_result\",\"def\":\"def get_result\\n  return 'hello'\\nend\"}",
      DONE_JSON
    )
    expected = LOG_START +
                 Regexp.escape('{"result":{"data":"hi"}}') +
                 '\r?\n' +
                 Regexp.escape('{"result":{"data":"hello"}}') +
                 '\r?\n' +
                 LOG_END
    expect{run_listen}.to output(/^#{expected}$/).to_stdout
  end

  it 'passes args to the function' do
    func = "def write_out(args={})\\n  m = [args['1'], args['2']]\\n  return m.join(' ')\\nend"
    allow($stdin).to receive(:gets).exactly(3).and_return(
      "{\"cmd\":\"get_result\",\"def\":\"#{func}\",\"args\":{\"1\":\"hello\", \"2\":\"there!\"}}",
      "{\"cmd\":\"get_result\",\"args\":{\"1\":\"bye\"}}",
      DONE_JSON
    )
    expected = LOG_START +
                 Regexp.escape('{"result":{"data":"hello there!"}}') +
                 '\r?\n' +
                 Regexp.escape('{"result":{"data":"bye "}}') +
                 '\r?\n' +
                 LOG_END
    expect{run_listen}.to output(/^#{expected}$/).to_stdout
  end

  context 'errors' do

    it "writes error when it can't parse json, and continues" do
      allow($stdin).to receive(:gets).twice.and_return(
        '{"cmd":"}',
        DONE_JSON
      )
      expected_err = Regexp.escape('{"error":{"message":"Could not parse JSON: {\"cmd\":\"}"')
      expected_log = Regexp.escape('{"log":{"severity":"error","message":"Could not parse JSON:')
      expect{run_listen}.to output(/^#{expected_err}/).to_stderr.and \
        output(/^#{expected_log}/).to_stdout
    end

    it "writes error when it can't find a function definition, and terminates" do
      allow($stdin).to receive(:gets).once.and_return(
        '{"cmd":"unknown"}'
      )
      expected_err = Regexp.escape('{"error":{"message":"Function definition for \'unknown\' not found"')
      expected_log = Regexp.escape('{"log":{"severity":"error","message":"Function definition for \'unknown\' not found')
      expect{run_listen}.to output(/^#{expected_err}/).to_stderr.and \
        output(/^#{expected_log}/).to_stdout.and raise_error(SystemExit)
    end

    it "writes error when it can't execute a function, and terminates" do
      allow($stdin).to receive(:gets).once.and_return(
        "{\"cmd\":\"get_result\",\"def\":\"def get_result\\n  retrn 'hi'\\nend\"}"
      )
      expected_err = Regexp.escape('{"error":{"message":"Could not execute get_result:')
      expected_log = Regexp.escape('{"log":{"severity":"error","message":"Could not execute get_result:')
      expect{run_listen}.to output(/^#{expected_err}/).to_stderr.and \
        output(/^#{expected_log}/).to_stdout.and raise_error(SystemExit)
    end

  end

end

################################################################################
