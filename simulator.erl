-module(simulator).
-compile(export_all).

-define(GRID_RANGE, 1).
-define(REGION_AROUND(Range, Multiplier), 
        [Multiplier * Coordinate || Coordinate <- lists:seq(-Range, Range)]).
-define(IN_LIST(ElementIndex, LengthOfList), 
        ((ElementIndex >= 1) and (ElementIndex =< LengthOfList)) ).
-define(IN_RANGE(NeighbourIndex, NodeIndex, LengthOfGrid), (not (
            (((NodeIndex - NeighbourIndex) == 1) and 
            ((NeighbourIndex rem LengthOfGrid) == 0)) 
        or  ((NodeIndex - NeighbourIndex) == -1) and 
            ((((NeighbourIndex - 1) rem LengthOfGrid) == 0))
        ))).

% [A] -> [{index_of_A, A}]
enumerate_list(List) ->
  LengthOfList = erlang:length(List),
  enumerate_list(List, LengthOfList).
enumerate_list(List, LengthOfList) ->
  lists:zip(lists:seq(1, LengthOfList), List).

% Finds the index of an element in a list, if it exists
find_index_of(RequiredElement, List) ->
  LengthOfList = erlang:length(List),
  find_index_of(RequiredElement, List, LengthOfList).
find_index_of(RequiredElement, List, LengthOfList) ->
  IndexList = [ElementIndex || 
               {ElementIndex, Element} <- enumerate_list(List, LengthOfList),
               Element == RequiredElement],
  case erlang:length(IndexList) of
    0 -> 'not_found'
  ; _ -> [First|_Rest] = IndexList, First
  end.

% Swaps the locations of two elements in a list
swap_elements_in(List, Index1, Index2) ->
  I1 = erlang:min(Index1, Index2),
  I2 = erlang:max(Index1, Index2),
  
  {List1, ListX} = lists:split(I1 - 1, List),
  {Element1, ListY} = lists:split(1, ListX),
  {List2, ListZ} = lists:split(I2 - I1 - 1, ListY),
  {Element2, List3} = lists:split(1, ListZ),
  
  List1 ++ Element2 ++ List2 ++ Element1 ++ List3.

% Returns a list of all available neighbours of the given process in the list of nodes
get_legal_neighbours_of(ProcessIndex, NumberOfNodes, TopologyType) ->
  LengthOfGrid = erlang:round(math:sqrt(NumberOfNodes)),
  case TopologyType of
    'full' ->
      
      NodesInRange = lists:seq(1, NumberOfNodes),
      IllegalNeighbours = [ProcessIndex]
  ; 'line' ->
      NodesInRange = [ProcessIndex + X || 
                      X <- ?REGION_AROUND(?GRID_RANGE, 1)],
      IllegalNeighbours = [ProcessIndex] ++ 
                          [NeighbourIndex || NeighbourIndex <- NodesInRange, 
                          (not ?IN_LIST(NeighbourIndex, NumberOfNodes))]
  ; '2D' ->
      NodesInRange = [ProcessIndex + X + Y || X <- ?REGION_AROUND(?GRID_RANGE, 1),
                       Y <- ?REGION_AROUND(?GRID_RANGE, LengthOfGrid)],
      IllegalNeighbours = [ProcessIndex] ++ 
                          [NeighbourIndex || NeighbourIndex <- NodesInRange,
                          (not ?IN_LIST(NeighbourIndex, NumberOfNodes)) or 
                          (not ?IN_RANGE(NeighbourIndex, ProcessIndex, LengthOfGrid))]
  ; 'imp3D' -> 
      NodesInRange = [ProcessIndex + X + Y || 
                       X <- ?REGION_AROUND(?GRID_RANGE, 1),
                       Y <- ?REGION_AROUND(?GRID_RANGE, LengthOfGrid)],
      IllegalNeighbours = [ProcessIndex] ++ 
                          [NeighbourIndex || NeighbourIndex <- NodesInRange,
                          (not ?IN_LIST(NeighbourIndex, NumberOfNodes)) or 
                          (not ?IN_RANGE(NeighbourIndex, ProcessIndex, LengthOfGrid))]
  end,
  LegalNeighbours = NodesInRange -- IllegalNeighbours, 
  LegalNeighbours.

node_create(Id) -> erlang:integer_to_list(Id) ++ " is alive!".

% Assign a Random Neighbour which is not Illegal 
assign_random_neighbour_from({NodeList, IllegalNeighboursList}, TopologyType) ->  
  NumberOfNodes = erlang:length(NodeList),
  RandomNodeIndex = rand:uniform(NumberOfNodes),
  RandomNode = lists:nth(RandomNodeIndex, NodeList),
  {RandomProcessIndex, _RandomProcess} = RandomNode,
  
  case lists:member(RandomProcessIndex, IllegalNeighboursList) of
    true -> assign_random_neighbour_from({NodeList, IllegalNeighboursList}, TopologyType)
  ; false -> RandomNode
  end.

% Assign Random Neighbours to elements of given NodeList for Imperfect 3D Topology
assign_random_neighbours_to({[], RandomProcessList}, _TopologyType) -> 
  RandomProcessList;
assign_random_neighbours_to({[_Node], RandomProcessList}, _TopologyType) -> 
  RandomProcessList;
assign_random_neighbours_to({NodeList, RandomProcessList}, TopologyType) -> 
  NumberOfNodes = erlang:length(NodeList),
  RandomNodeIndex = rand:uniform(NumberOfNodes),
  RandomNode = lists:nth(RandomNodeIndex, NodeList),
  {RandomProcessIndex, _RandomProcess} = RandomNode,
  
  NumberOfProcesses = erlang:length(RandomProcessList),
  LegalNeighboursList = get_legal_neighbours_of(RandomProcessIndex, NumberOfProcesses, TopologyType),
  IllegalNeighboursList = LegalNeighboursList ++ [RandomProcessIndex],
  
  RandomNeighbourNode = assign_random_neighbour_from({NodeList, IllegalNeighboursList}, TopologyType), 
  {RandomNeighbourProcessIndex, _RandomNeighbourProcess} = RandomNeighbourNode,

  NewRandomProcessList = swap_elements_in(RandomProcessList, 
                          RandomProcessIndex, RandomNeighbourProcessIndex),
  NewNodeList = NodeList -- [RandomNode, RandomNeighbourNode],
  
  assign_random_neighbours_to({NewNodeList, NewRandomProcessList}, TopologyType);  
assign_random_neighbours_to(NodeList, TopologyType) -> 
  RandomProcessList = NodeList,
  NewNodeList = enumerate_list(NodeList),
  assign_random_neighbours_to({NewNodeList, RandomProcessList}, TopologyType).

%% Returns a (randomly selected) neighbour process of the specified process
get_random_neighbour_for(ProcessId, {NodeList, RandomNodeList}, TopologyType) -> 
  NumberOfNodes = erlang:length(NodeList),
  ProcessIndex = find_index_of(ProcessId, NodeList, NumberOfNodes),
  LegalNeighboursList = get_legal_neighbours_of(
                          ProcessIndex, NumberOfNodes, TopologyType),
  NeighbouringProcessesId = [lists:nth(Index, NodeList) 
                            || Index <- LegalNeighboursList],
  case TopologyType of
    'imp3D' -> 
      AllNeighbouringProcessesId = NeighbouringProcessesId ++ 
                                    lists:nth(ProcessIndex, RandomNodeList)
  ; _ -> 
      AllNeighbouringProcessesId = NeighbouringProcessesId
  end,
  RandomProcessIndex = rand:uniform(erlang:length(AllNeighbouringProcessesId)),
  RandomProcessId = lists:nth(RandomProcessIndex, AllNeighbouringProcessesId),
  RandomProcessId.