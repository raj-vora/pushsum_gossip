-module(pushsumgossip).

-compile(export_all).

masternode(Topology, Algorithm, [], [], Start) ->
    TimeDifference =
        timer:now_diff(
            erlang:timestamp(), Start)
        / 1000,
    io:format("Time Taken: ~p ms.~n", [TimeDifference]),
    exit(self(), converged),
    masternode(Topology, Algorithm, [], [], Start);
masternode(Topology, Algorithm, [], Random_Node_List, Start) ->
    TimeDifference =
        timer:now_diff(
            erlang:timestamp(), Start)
        / 1000,
    io:format("Time Taken: ~p ms.~n", [TimeDifference]),
    exit(self(), converged),
    masternode(Topology, Algorithm, [], Random_Node_List, Start);
masternode(Topology, Algorithm, Node_List, Random_Node_List, Start) ->
    [First | _] = Node_List,
    if Algorithm == gossip ->
           First ! {self(), rumour};
       Algorithm == 'push-sum' ->
           First ! {self(), {2, 1}}
    end,
    receive
        {Node_ID, request_neighbour} ->
            if erlang:length(Node_List) == 1 ->
                   masternode(Topology, Algorithm, [], Random_Node_List, Start);
               true ->
                   Random_Neighbour =
                       simulator:get_random_neighbour_for(Node_ID,
                                                          {Node_List, Random_Node_List},
                                                          Topology),
                   Node_ID ! {self(), Random_Neighbour},
                   masternode(Topology, Algorithm, Node_List, Random_Node_List, Start)
            end;
        {Node_ID, done} ->
            if Topology == imp3D ->
                   {New_Node_List, New_Random_Node_List} =
                       remove_from_list(Node_ID, {Node_List, Random_Node_List});
               true ->
                   {New_Node_List, New_Random_Node_List} = remove_from_list(Node_ID, Node_List)
            end,
            masternode(Topology, Algorithm, New_Node_List, New_Random_Node_List, Start)
    end.

remove_from_list(Node_ID, {Node_List, Random_Node_List}) ->
    Node_Member = lists:member(Node_ID, Node_List),
    Random_Node_Member = lists:member(Node_ID, Random_Node_List),
    if Node_Member ->
           {lists:delete(Node_ID, Node_List), Random_Node_List};
       true ->
           {Node_List, Random_Node_List}
    end,
    if Random_Node_Member ->
           {Node_List, lists:delete(Node_ID, Random_Node_List)};
       true ->
           {Node_List, Random_Node_List}
    end;
remove_from_list(Node_ID, Node_List) ->
    Node_Member = lists:member(Node_ID, Node_List),
    if Node_Member ->
           {lists:delete(Node_ID, Node_List), []};
       true ->
           {Node_List, []}
    end.

main(N, Topology, Algorithm) ->
    if Algorithm == gossip ->
           Node_List = create_gossip_nodes(N, []),
           Random_Node_List = simulator:assign_random_neighbours_to(Node_List, Topology),
           Start = erlang:timestamp(),
           register(masternode,
                    spawn(?MODULE,
                          masternode,
                          [Topology, Algorithm, Node_List, Random_Node_List, Start]));
       Algorithm == 'push-sum' ->
           Node_List = create_pushsum_nodes(N, []),
           Random_Node_List = simulator:assign_random_neighbours_to(Node_List, Topology),
           Start = erlang:timestamp(),
           register(masternode,
                    spawn(?MODULE,
                          masternode,
                          [Topology, Algorithm, Node_List, Random_Node_List, Start]));
       true ->
           ok
    end.

create_gossip_nodes(Times, Node_List) ->
    if Times > 0 ->
           %    Node_Name =
           %        erlang:list_to_atom(
           %            lists:flatten(
           %                io_lib:format("node~s", [erlang:integer_to_list(Times)]))),
           Pid = spawn(?MODULE, gossip_node, [0]),
           New_List = [Pid | Node_List],
           create_gossip_nodes(Times - 1, New_List);
       true ->
           Node_List
    end.

create_pushsum_nodes(Times, Node_List) ->
    if Times > 0 ->
           %    NodeName =
           %        erlang:list_to_atom(
           %            lists:flatten(
           %                io_lib:format("node~s", [erlang:integer_to_list(Times)]))),
           Pid = spawn(?MODULE, pushsum_node, [Times, 1, 0]),
           New_List = [Pid | Node_List],
           create_pushsum_nodes(Times - 1, New_List);
       true ->
           Node_List
    end.

gossip_node(Count) ->
    receive
        {Masternode_ID, rumour} ->
            if Count < 9 ->
                   NewCount = Count + 1,
                   Masternode_ID ! {self(), request_neighbour},
                   gossip_node(NewCount);
               Count == 9 ->
                   Masternode_ID ! {self(), done},
                   gossip_node(Count);
               true ->
                   gossip_node(Count)
            end;
        {Masternode_ID, Neighbour} ->
            Neighbour ! {Masternode_ID, rumour},
            gossip_node(Count)
    end.

pushsum_node(SelfS, SelfW, Consecutive) ->
    receive
        {Masternode_ID, {S, W}} ->
            NewSelfS = (SelfS + S) / 2,
            NewSelfW = (SelfW + W) / 2,
            OldRatio = SelfS / SelfW,
            NewRatio = NewSelfS / NewSelfW,
            if NewRatio - OldRatio < 1.0e-2 ->
                   if Consecutive == 3 ->
                          Masternode_ID ! {self(), done};
                      true ->
                          New_Consecutive = Consecutive + 1,
                          Masternode_ID ! {self(), request_neighbour},
                          pushsum_node(NewSelfS, NewSelfW, New_Consecutive)
                   end;
               true ->
                   Masternode_ID ! {self(), request_neighbour},
                   pushsum_node(NewSelfS, NewSelfW, Consecutive)
            end;
        {Masternode_ID, Neighbour} ->
            Neighbour ! {Masternode_ID, {SelfS, SelfW}},
            pushsum_node(SelfS, SelfW, Consecutive)
    end.
