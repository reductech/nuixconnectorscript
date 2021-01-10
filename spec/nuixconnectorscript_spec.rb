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
