require_relative "spec_helper"

describe "Clustering" do
  subject { Jylis.new(opts) }
  
  # Use a very short heartbeat time to speed up cluster establishment.
  let(:opts) { { heartbeat_time: 0.05 } }
  
  it "allows nodes to share data with eachother" do
    subject.run do
      # Create two more nodes which use the first node as a seed.
      node2 = Jylis.new(seed_addrs: subject.addr, **opts)
      node3 = Jylis.new(seed_addrs: subject.addr, **opts)
      nodes = [subject, node2, node3]
      
      # Run the other two nodes.
      node2.run do
        node3.run do
          # Wait to establish a fully connected cluster.
          nodes.each do |a|
            nodes.each do |b|
              next if a == b
              a.await_line "active cluster connection established to: #{b.addr}"
            end
          end
          
          # Expect to be able to write data on node2 and read it on node3.
          node2.call(%w[TREG SET key1 foo 7]).should eq "OK"
          node3.await_call_result(%w[TREG GET key1], ["foo", 7])
        end
      end
    end
  end
  
  it "catches up a new node to data that was written before it connected" do
    subject.run do
      # Create two more nodes which use the first node as a seed.
      node2 = Jylis.new(seed_addrs: subject.addr, **opts)
      node3 = Jylis.new(seed_addrs: subject.addr, **opts)
      nodes = [subject, node2, node3]
      
      # Run the second node.
      node2.run do
        # Write some data to node2.
        node2.call(%w[TREG SET key1 foo 7]).should eq "OK"
        
        # Expect the data to become visible on node3 after it starts up.
        node3.run do
          node3.await_call_result(%w[TREG GET key1], ["foo", 7])
        end
      end
    end
  end
end
