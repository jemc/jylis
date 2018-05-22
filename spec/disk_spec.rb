require_relative "spec_helper"

require "securerandom"
require "fileutils"

describe "Disk persistence" do
  subject { Jylis.new(disk_dir: disk_dir) }
  
  let(:disk_dir) { "/tmp/jylis-spec-#{SecureRandom.hex(8)}" }
  after { FileUtils.remove_dir(disk_dir) }
  
  it "saves to and loads from an append-only file with a predictable format" do
    subject.disk.keys.should be_empty
    
    subject.run do
      subject.call(%w[TREG SET key1 foo 7]).should eq "OK"
    end
    
    subject.disk.keys.should include "append.SYSTEM.jylis"
    subject.disk.keys.should include "append.TREG.jylis"
    
    subject.disk["append.TREG.jylis"].read.should eq \
      %w[*2 *3 :0 *0 *0 *2 $4 key1 *2 $3 foo :7].join("\r\n") + "\r\n"
    
    subject.run do
      subject.call(%w[TREG GET key1]).should eq ["foo", 7]
      subject.call(%w[TREG SET key2 bar 8]).should eq "OK"
    end
    
    subject.disk["append.TREG.jylis"].read.should eq \
      %w[*2 *3 :0 *0 *0 *2 $4 key1 *2 $3 foo :7
         *2 *3 :0 *0 *0 *2 $4 key2 *2 $3 bar :8].join("\r\n") + "\r\n"
    
    subject.run do
      subject.call(%w[TREG GET key1]).should eq ["foo", 7]
      subject.call(%w[TREG GET key2]).should eq ["bar", 8]
      subject.call(%w[TREG SET key3 baz 9]).should eq "OK"
    end
    
    subject.disk["append.TREG.jylis"].read.should eq \
      %w[*2 *3 :0 *0 *0 *2 $4 key1 *2 $3 foo :7
         *2 *3 :0 *0 *0 *2 $4 key2 *2 $3 bar :8
         *2 *3 :0 *0 *0 *2 $4 key3 *2 $3 baz :9].join("\r\n") + "\r\n"
  end
end
