%Class that represents a simple Sensor
-module(class_Car).

% Determines what are the mother classes of this class (if any):
-define( wooper_superclasses, [ class_Actor ] ).

% parameters taken by the constructor ('construct').
-define( wooper_construct_parameters, ActorSettings, CarName, KnowRoutePID).

% Declaring all variations of WOOPER-defined standard life-cycle operations:
% (template pasted, just two replacements performed to update arities)
-define( wooper_construct_export, new/3, new_link/3,
		 synchronous_new/3, synchronous_new_link/3,
		 synchronous_timed_new/3, synchronous_timed_new_link/3,
		 remote_new/4, remote_new_link/4, remote_synchronous_new/4,
		 remote_synchronous_new_link/4, remote_synchronisable_new_link/4,
		 remote_synchronous_timed_new/4, remote_synchronous_timed_new_link/4,
		 construct/4, destruct/1 ).

% Method declarations.
-define( wooper_method_export, actSpontaneous/1, onFirstDiasca/2, go/3, wait_semaphore/3, signal_answer/3).


% Allows to define WOOPER base variables and methods for that class:
-include("smart_city_test_types.hrl").

% Allows to define WOOPER base variables and methods for that class:
-include("wooper.hrl").


% Must be included before class_TraceEmitter header:
-define(TraceEmitterCategorization,"Smart-City.Car").


% Allows to use macros for trace sending:
-include("class_TraceEmitter.hrl").



% Creates a new car
%
-spec construct( wooper:state(), class_Actor:actor_settings(),
				class_Actor:name(), pid()) -> wooper:state().
construct( State, ?wooper_construct_parameters ) ->

	ActorState = class_Actor:construct( State, ActorSettings, CarName ),

	% Depending on the choice of the result manager, it will be either a PID (if
	% the corresponding result is wanted) or a 'non_wanted_probe' atom:
%	StockProbePid = class_Actor:declare_probe(
%		_Name=io_lib:format( "~s Car Name Probe", [ CarName ] ),
%		_Curves=[ io_lib:format( "~s speed", [ CarName ] ) ],
%		_Zones=[],
%		_Title="Long",
%		_XLabel="Lat",
%		_YLabel="Car Speed over the simulation time" ),

	setAttributes( ActorState, [
		{ car_name, CarName },
		{ known_route_pid, KnowRoutePID },
		{ car_position, 0 },
		{ speed, 0 },
		{ index, 1 },
		{ probe_pid, non_wanted_probe },
		{ next_move_tick, 1 },
		{ trace_categorization,
		 text_utils:string_to_binary( ?TraceEmitterCategorization ) }
							] ).

% Overridden destructor.
%
-spec destruct( wooper:state() ) -> wooper:state().
destruct( State ) ->

	% Destructor don't do nothing in this class.

	State.

% The core of the car behaviour.
%
% (oneway)
%
-spec actSpontaneous( wooper:state() ) -> oneway_return().
actSpontaneous( State ) ->

	case is_to_move( State ) of

		true ->
			NewState = request_position( State ),
	
			?wooper_return_state_only( NewState );
		false -> 
			executeOneway( State, scheduleNextSpontaneousTick )
	end.

-spec request_position( wooper:state() ) -> wooper:state().
request_position( State ) ->

	Index = getAttribute(State, index),
	
	class_Actor:send_actor_message( ?getAttr(known_route_pid),
		{ getPosition, Index }, setAttribute(State, car_position, 25) ).

	

% Called by the route with the requested position. Write the file to show the position of the car in the map.
%
% (actor oneway)
%
-spec go( wooper:state(), car_position(), pid() ) -> class_Actor:actor_oneway_return().
go( State, Position, _MachinePid ) ->
	
	move ( State , Position ).

-spec move( wooper:state(), car_position() ) -> class_Actor:actor_oneway_return().
move( State, Position ) ->
	
	NewState = setAttribute( State, car_position, Position ),
	
	Lat = element(1,Position),
	Long = element(2,Position),
	
	Index = getAttribute(State, index),

	CarName = getAttribute(State, car_name),

	Speed = getAttribute(State, speed)
		+ class_RandomManager:get_positive_integer_gaussian_value(
			_Mu=5, _Sigma=4.0 ),

	Filename = text_utils:format(
				 "/home/eduardo/sc-monitor/locations/cars/~s.xml",
				 [ CarName ] ),

	InitFile = file_utils:open( Filename, _Opts=[ write, delayed_write ] ),

	file_utils:write( InitFile, "<locations>", [] ),
	file_utils:write( InitFile, "<speed>Speed:~w </speed>", [ Speed  ] ),
	file_utils:write( InitFile, "<lat> ~w </lat>", [ Lat  ] ),
	file_utils:write( InitFile, "<long> ~w </long>", [ Long  ] ),
	file_utils:write( InitFile, "</locations>", [] ),
		
	file_utils:close( InitFile ),
	
	NewStateIndex = setAttribute(NewState, index, Index + 1),


	NewStateSpeed = case Speed > 50 of

		true ->
			setAttribute(NewStateIndex, speed, 50);
		false -> 
			setAttribute(NewStateIndex, speed, Speed)
	end,

%	class_Probe:send_data( ?getAttr(probe_pid),
%	 	class_Actor:get_current_tick( NewStateSpeed ),
%		{ getAttribute( NewStateSpeed , speed ) } ),

	CurrentTick = class_Actor:get_current_tick( NewStateIndex ),

	NextMove = 60 - getAttribute(State, speed),

	TickDuration = class_Actor:convert_seconds_to_non_null_ticks(
					 NextMove, _MaxRelativeErrorForTest=0.50, NewStateSpeed ),

	TickState = setAttribute( NewStateSpeed, next_move_tick,
								 CurrentTick + TickDuration ),	
	
	executeOneway( TickState, scheduleNextSpontaneousTick).


% Called by the route with the requested position. Write the file to show the position of the car in the map.
%
% (actor oneway)
%
-spec wait_semaphore( wooper:state(), value(), pid() ) -> class_Actor:actor_oneway_return().
wait_semaphore( State, SemaphoreValue, _MachinePid ) ->

	SEM_ID = element(3, SemaphoreValue),

	STATE = element(4, SemaphoreValue),

%	class_Probe:send_data( ?getAttr(probe_pid),
%	 	class_Actor:get_current_tick( State ),
%		{ getAttribute( State , speed ) } ),

 	class_Actor:send_actor_message( SEM_ID,
		{ get_signal, { STATE , SemaphoreValue } }, State ).


-spec signal_answer( wooper:state(), value(), pid() ) ->
					   class_Actor:actor_oneway_return().
signal_answer( State, Values , _SemID ) ->

	Signal_State = element( 1 , Values ),
	
	case Signal_State of

		green->

			move ( State , element( 2 , Values ) );

		red ->

			NewState = setAttribute(State, speed, 0),
			%try again
			executeOneway( NewState , scheduleNextSpontaneousTick )

	end.

% Returns if the car has to move
%
% (helper)
%
-spec is_to_move( wooper:state() ) -> boolean().
is_to_move( State ) ->

	CurrentTick = class_Actor:get_current_tick( State ),

	case ?getAttr(next_move_tick) of

		MoveTick when CurrentTick >= MoveTick ->
			true;

		_ ->
			false

	end.


% Simply schedules this just created actor at the next tick (diasca 0).
%
% (actor oneway)
%
-spec onFirstDiasca( wooper:state(), pid() ) -> oneway_return().
onFirstDiasca( State, _SendingActorPid ) ->

	SimulationInitialTick = ?getAttr(initial_tick),

	% Checking:
	true = ( SimulationInitialTick =/= undefined ),

	case ?getAttr(probe_pid) of

		non_wanted_probe ->
			ok;

		ProbePid ->
			ProbePid ! { setTickOffset, SimulationInitialTick }

	end,

	ScheduledState = executeOneway( State, scheduleNextSpontaneousTick ),

	?wooper_return_state_only( ScheduledState ).


