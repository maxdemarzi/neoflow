require 'rubygems'
require 'neography'
require 'sinatra'
require 'uri'

require 'net-http-spy'
Net::HTTP.http_logger_options = {:verbose => true} # see everything

def create_graph
  neo = Neography::Rest.new
  graph_exists = neo.get_node_properties(1)
  return if graph_exists && graph_exists['name']

  states = [{:name => "California", :coordinates => [-119.355165,35.458606]},
            {:name => "Illinois",   :coordinates => [ -88.380238,41.278216]},
            {:name => "Texas",      :coordinates => [ -97.388631,30.943149]}
          ]

  commands = states.map{ |n| [:create_node, n]}
  
  states.each_index.map do  |n| 
    commands << [:add_node_to_index, "states_index", "name", states[n][:name], "{#{n}}"] 
  end
  
  commands << [:create_relationship, "connected", "{#{0}}", "{#{1}}", {:capacity => 1}]    
  commands << [:create_relationship, "connected", "{#{0}}", "{#{1}}", {:capacity => 2}]
  commands << [:create_relationship, "connected", "{#{0}}", "{#{2}}", {:capacity => 1}]
  commands << [:create_relationship, "connected", "{#{2}}", "{#{1}}", {:capacity => 3}]

  batch_result = neo.batch *commands
end
  
def max_flow
  neo = Neography::Rest.new
  neo.execute_script("source = g.idx('states_index')[[name:'California']].iterator().next(); 
                      sink = g.idx('states_index')[[name:'Illinois']].iterator().next();
                      
                      max_flow = 0;
                      g.setMaxBufferSize(0);
                      g.startTransaction();
                       
                      source.outE.inV.loop(2){
                        !it.object.equals(sink)}.
                      paths.each{
                        flow = it.capacity.min();
                        max_flow += flow;
                        it.findAll{
                          it.capacity}.each{
                            it.capacity -= flow}
                            };
                      g.stopTransaction(TransactionalGraph.Conclusion.FAILURE); 
                            
                      max_flow;")
end  

get '/max_flow' do
  max_flow.to_json
end
