require_relative "spec_helper"

require "securerandom"
require "fileutils"

describe "System functions" do
  subject { Jylis.new }
  
  describe "FORGETALL" do
    it "saves to and loads from an append-only file with a predictable format" do
      subject.run do
        subject.call(%w[TREG SET key1 foo 7]).should eq "OK"
        subject.call(%w[TREG GET key1]).should eq ["foo", 7]
        
        subject.call(%w[SYSTEM FORGETALL]).should eq "OK"
        subject.call(%w[TREG GET key1]).should eq ["", 0]
        
        subject.call(%w[TREG SET key1 bar 8]).should eq "OK"
        subject.call(%w[TREG GET key1]).should eq ["bar", 8]
        
        subject.call(%w[SYSTEM FORGETALL]).should eq "OK"
        subject.call(%w[TREG GET key1]).should eq ["", 0]
        
        subject.call(%w[TREG SET key1 baz 9]).should eq "OK"
        subject.call(%w[TREG GET key1]).should eq ["baz", 9]
      end
    end
  end
end
