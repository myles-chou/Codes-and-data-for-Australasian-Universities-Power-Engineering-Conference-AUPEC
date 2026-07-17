
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Basic sets
%
% EV group
% EV pot
%
% Charging stations
% fast-charging and slow-charging stations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Set of EV groups
enum EVGroup = {A, B, C};

% Set of EV pots
enum EVPot = {
    Glenorchy,
    West_Moonah,
    New_Town,
    North_Hobart,
    South_Hobart,
    Bellerive,
    Warrane
};

% Set of charging stations
enum ChargingStation = {
    G1, G2,
    W1, W2,
    N1, N2,
    S1, S2, S3, S4, S5, S6, S7, S8, S9, S10,
    B1, B2, B3
};

% Set of fast-charging stations
set of ChargingStation: FastChargingStations = {
    G1, G2,
    W1, W2,
    S3, S8, S10,
    B2, B3
};

% Set of slow-charging stations
set of ChargingStation: SlowChargingStations = {
    N1, N2,
    S1, S2,
    S4, S5, S6, S7, S9,
    B1, 
};


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Consant parameters
%
% monetary waiting time 
% monetary driging time 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Monetary waiting and driving time cost
int:a_wait = 6; % per hour
int:b_drive = 18; % per hour


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Time settings
%
% Timeslot:1, ..., 32,33
% Index order: [TimeSlot, ChargingStation]
%
% time_mins: 0, 15, 30,,, 450, 465, 480
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Time horizon: 0 to 480 minutes (8 hours) in 15-minute intervals
int: TIME_HORIZON = 480;
int: SLOT_LENGTH  = 60;

% Time-slot indices: 1, ..., 32,33
set of int: TimeSlot = 1..(TIME_HORIZON div SLOT_LENGTH)+1;

% Actual time represented by each slot, in minutes [0, 15, 30,,, 450, 465, 480]
% e.g., time_mins[1] = 0, time_mins[33] = 480
array[TimeSlot] of int: time_mins =
    [(t-1) * SLOT_LENGTH | t in TimeSlot];
    
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Time set finding (no later than t)
%
% Function:  time_points_no_later_than
% Array: TimePointsNoLaterThan

%
% time_points_no_later_than(30)= {0,15,30}
% TimePointsNoLaterThan[2]= {0, 15}
% time_points_no_later_than_depart: depart to arrive before t
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
     
% Returns all time-slot indices no later than time slot t
% e.g., time_points_no_later_than(30)= {0,15,30}
%       time_points_no_later_than(0)= {0}
function set of int: time_points_no_later_than(int: t) =
    {tau | tau in time_mins where tau <= t};
    
% Optional: precompute the set for every time slot
% e.g., TimePointsNoLaterThan[1]=0..0
%       TimePointsNoLaterThan[33]={0,15,30,45,60,75,90,105,120,135,150,165,180,195,210,225,
%                                 240,255,270,285,300,315,330,345,360,375,390,405,420,435,450,465,480}

% if you want to find the time set no later than t, you should use
% TimePointsNoLaterThan[time_slot_of(t)]  
% e.g., TimePointsNoLaterThan[time_slot_of(30)]--{0,15}
array[TimeSlot] of set of int: TimePointsNoLaterThan =
    [time_points_no_later_than(t) | t in time_mins]; 
% TimeSlot = 1..33


% Returns all time-slot indices no later than time slot t
% Departure time set For EVs from pot to station, should arrive no later than t
% If you want to arrive at station s before t, you should departs from pot p no later than  
% time_points_no_later_than_depart(t, p, s)
% e.g., driving_time_mins[Glenorchy,G1] = 5, then 
%       time_points_no_later_than_depart(30, Glenorchy,G1) = {0, 15}
%       time_points_no_later_than_depart(125, Glenorchy,G1) = {0,15,30,45,60,75,90,105,120}
function set of int: time_points_no_later_than_depart(int: t, EVPot: pot, ChargingStation: station) =
    {tau | tau in time_mins where tau <= t-driving_time_mins[pot,station]};

%array format with TimeSlot
% EligibleDepartureSlots[]    
array[
    TimeSlot,
    EVPot,
    ChargingStation
] of set of int: EligibleDepartureSlots =
    array3d(
        TimeSlot,
        EVPot,
        ChargingStation,
        [
            time_points_no_later_than_depart(t, pot, charge)
            | t in time_mins,
              pot in EVPot,
              charge in ChargingStation
        ]
    );
% TimeSlot = 1..33
% e.g., EligibleDepartureSlots[time_slot_of(30), Glenorchy,G1]= {0, 15}
%       EligibleDepartureSlots[time_slot_of(125), Glenorchy,G1]= {0, 15}-error
%       EligibleDepartureSlots[time_slot_of(135), Glenorchy,G1]= {0,15,30,45,60,75,90,105,120}    
      
      
      
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Convert mins to Timeslot
%
% Function:  time_slot_of(int: minute)
% ime_slot_of(0) = 1
%
% ime_slot_of(480) = 33
% ime_slot_of(time_mins[a]) = a
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        

% e.g., time_slot_of(0) = 1; time_slot_of(480) = 33  
% Tip: time_slot_of(time_mins[a]) = a
function int: time_slot_of(int: minute) =
    assert(
        minute in time_mins,
        "The specified time must be a valid 15-minute time point.",
        1+ minute div SLOT_LENGTH
    );



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Preset arrays
%
% driving_time_mins
% capacity_demand, ev_demand
%
% price: station_base_price, time_price_adjustment, station_charging_price
% Power capacity: station_design_capacity, capacity_availability_percent, 
%                 design_capacity
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  

% driving time from pot i to charging station s
array[EVPot, ChargingStation] of int: driving_time_mins =
[|
%  G1  G2  W1  W2  N1  N2  S1  S2  S3  S4  S5  S6  S7  S8  S9 S10  B1  B2  B3

    1,  4,  6,  7, 11, 12, 14, 15, 16, 16, 19, 17, 16, 21, 19, 20, 17, 18, 21
|   7,  6,  5,  5, 10, 12, 16, 16, 18, 16, 16, 18, 17, 22, 20, 21, 18, 18, 24
|   9,  7,  3,  1,  2,  6,  9,  9, 10,  9, 11, 10, 10, 14, 13, 14, 10, 10, 16
|  14, 10,  7,  7,  1,  2,  8,  7,  8,  7,  6,  8,  7, 12, 11, 12, 10, 10, 16
|  21, 18, 14, 13,  9,  8,  7,  7,  4,  5,  4,  3,  3,  5,  4,  7, 11, 12, 17
|  19, 19, 13, 13, 12, 12,  9, 11, 10,  8, 14, 10, 10, 15, 14, 15,  3,  4, 11
|  18, 17, 13, 14, 12, 11, 12, 11, 13, 11, 14, 13, 11, 16, 15, 16,  3,  5, 10
|];

% 250 kW- 2026 Tesla Model 3 Specs
array[EVGroup] of int: capacity_demand = [
    50,    % Group A: 5%
    80,   % Group B: 50%
    110    % Group C: 70%
];
array[EVPot, EVGroup] of int: ev_demand =
[|
%       A   B   C
        12,  8,  5   % Glenorchy
|       10,  7,  4   % West_Moonah
|       16, 12,  6   % New_Town
|       20, 30, 12   % North_Hobart
|       18, 30, 18   % South_Hobart
|       11,  6,  5   % Bellerive
|        5,  8, 12   % Warrane
|];

%array[EVPot, EVGroup] of int: ev_demand =
%[|
%       A   B   C
%        6,  4,  2   % Glenorchy
%|       5,  3,  2   % West_Moonah
%|       8,  6,   3   % New_Town
%|       10, 20, 6   % North_Hobart
%|       9,  15, 9   % South_Hobart
%|       5,  3,  2   % Bellerive
%|        2,  4, 6   % Warrane
%|];


% Base charging price for each charging station
% Unit A$/10 kWh
array[ChargingStation] of int: station_base_price =
[
    7, 6,          % G1, G2
    7, 8,          % W1, W2
    8, 8,          % N1, N2
    8, 7, 7, 5,  % S1, S2, S3, S4
    5, 5, 8, 8,  % S5, S6, S7, S8
    8, 7,          % S9, S10
    8, 6, 6       % B1, B2, B3
];




% Time-of-use adjustment in cents per kWh
function int: time_price_adjustment(TimeSlot: t) =
    if time_mins[t] <= 120 then
        0       % Off-peak period
    elseif time_mins[t] <= 240 then
        0       % Shoulder period
    elseif time_mins[t] <= 390 then
        0      % Peak period
    else
        0       % Evening shoulder period
    endif;

% Charging price at station s during time slot t
% TimeSlot: 1..33
% station_charging_price [1,B3]=36
array[TimeSlot, ChargingStation] of int: station_charging_price =
    array2d(
        TimeSlot,
        ChargingStation,
        [
            station_base_price[s] + time_price_adjustment(t)
            | t in TimeSlot,
              s in ChargingStation
        ]
    );


% Nominal design capacity of each charging station, in kW/h
array[ChargingStation] of int: station_design_capacity =
[
    240, 1000,             % G1, G2
    320, 1000,             % W1, W2
    21,  21,               % N1, N2
    22,  22, 100, 21,      % S1, S2, S3, S4
    21, 14, 116, 120,      % S5, S6, S7, S8
    42, 400,               % S9, S10
    22,  320,  200         % B1, B2, B3
];


% Single connector capacity, in kW/h
array[ChargingStation] of int: single_connector_capacity =
[
    80, 250,             % G1, G2
    80, 250,             % W1, W2
    7,  7,               % N1, N2
    11, 11, 50, 7,      % S1, S2, S3, S4
    7,  7,  25, 60,      % S5, S6, S7, S8
    7,  80,               % S9, S10
    22, 80, 50         % B1, B2, B3
];

% Available connectors
array[ChargingStation] of float: connector_num = array1d(ChargingStation, 
                                                         [station_design_capacity[s]/single_connector_capacity[s]|s in ChargingStation]);

% Percentage of nominal capacity available during each time period
function int: capacity_availability_percent(TimeSlot: t) =
    if time_mins[t] <= 120 then
        100     % Full capacity
    elseif time_mins[t] <= 240 then
        100      % Slight reduction
    elseif time_mins[t] <= 390 then
        100      % Peak-period reduction
    else
        100      % Evening availability
    endif;

% Available capacity at station s during time slot t
% design_capacity[33, S10] = 300
array[TimeSlot, ChargingStation] of int: design_capacity =
    array2d(
        TimeSlot,
        ChargingStation,
        [
            station_design_capacity[s]
            * capacity_availability_percent(t)
            div 100
            | t in TimeSlot,
              s in ChargingStation
        ]
    );
    
array[TimeSlot, ChargingStation] of int: design_connector_capacity =
    array2d(
        TimeSlot,
        ChargingStation,
        [
            single_connector_capacity[s]
            * capacity_availability_percent(t)
            div 100
            | t in TimeSlot,
              s in ChargingStation
        ]
    );


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Decision variable: assigned EVs
%
% At origins: assigned_evs[pot, group, t, station]
% 
% At destinations: assigned_evs_dest[pot, group, t, station]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

int: MAX_EV_DEMAND =
    max(pot in EVPot, group in EVGroup)(
        ev_demand[pot, group]
    );
    
% assigned EV at starting pot
% TimeSlot: 1..33 not 0, 15, ..., 480
array[
    EVPot,
    EVGroup,
    TimeSlot,
    ChargingStation
] of var 0..MAX_EV_DEMAND: assigned_evs_origin; 

% successful charging EV at charging station
array[
    EVPot,
    EVGroup,
    TimeSlot,
    ChargingStation
] of var 0..MAX_EV_DEMAND: assigned_evs_dest; 



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Dependent variable: group_charging
%
% Revenue: R
% 
% Cost: C_w, C_d
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
% assigned EV at starting pot
% TimeSlot: 1..33 not 0, 15, ..., 480
array[
    EVGroup,
    TimeSlot,
    ChargingStation
] of var 0..MAX_EV_DEMAND: group_charging; 

% Systen revenue
var 1..100000000: R;
% waiting cost
var 1..100000000: C_w;
% driving cost
var 1..100000000: C_d;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Constraints
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
% Assignment conservation constraint (origin)
% Every EV belonging to group g at EV pot i must be assigned to exactly
% one departure time slot and one charging station.
constraint
    forall(
        pot in EVPot,
        group in EVGroup
    ) (
        sum(
            t in TimeSlot,
            station in ChargingStation
        ) (
            assigned_evs_origin[pot, group, t, station]
        )
        =
        ev_demand[pot, group]
    );


% Charging conservation constraint (destination)
%
% Every EV belonging to group g and originating from EV pot i must

constraint
    forall(
        pot in EVPot,
        group in EVGroup
    ) (
        sum(
            t in TimeSlot,
            station in ChargingStation
        ) (
            assigned_evs_dest[pot, group, t, station]
        )
        =
        ev_demand[pot, group]
    );


% Temporal consistency constraint
%
% EVs from a given pot and group may charge at station "station" during
% time slot "t" only if they were previously assigned to depart for the
% same station early enough to complete the required driving time.

constraint
    forall(
        pot in EVPot,
        group in EVGroup,
        t in TimeSlot,
        station in ChargingStation
    ) (
        assigned_evs_dest[pot, group, t, station]
        <=
        sum(
            depart_min in EligibleDepartureSlots[t, pot, station]
        ) (
            assigned_evs_origin[
                pot,
                group,
                time_slot_of(depart_min),
                station
            ]
        )
    );
    
 
       
% Cumulative temporal flow-consistency constraint
% By time slot t, the cumulative number of EVs from a given pot and group
% that have successfully reached and charged at station "station" cannot
% exceed the cumulative number assigned to depart sufficiently early to
constraint
    forall(
        pot in EVPot,
        group in EVGroup,
        t in TimeSlot,
        station in ChargingStation
    ) (
        sum(
            arrival_min in TimePointsNoLaterThan[t]
        ) (
            assigned_evs_dest[
                pot,
                group,
                time_slot_of(arrival_min),
                station
            ]
        )
        <=
        sum(
            depart_min in EligibleDepartureSlots[t, pot, station]
        ) (
            assigned_evs_origin[
                pot,
                group,
                time_slot_of(depart_min),
                station
            ]
        )
    );    



% Charging-flow aggregation constraint
%
% group_charging[group, t, station] represents the total number of EVs
% from group "group" charging at station "station" during time slot "t",
% aggregated across all EV pots.
constraint
    forall(
        group in EVGroup,
        t in TimeSlot,
        station in ChargingStation
    ) (
        group_charging[group, t, station]
        =
        sum(pot in EVPot) (
            assigned_evs_dest[pot, group, t, station]
        )
    );
 
 

% Fast-charging station capacity constraint
%
% At each fast-charging station and time slot, the total charging-capacity
% demand of all charging EVs must not exceed the available station capacity.


constraint
    forall(
        t in TimeSlot,
        station in FastChargingStations
    ) (
        sum(group in EVGroup) (
            capacity_demand[group]
            * group_charging[group, t, station]
        )
        <=
        design_capacity[t, station]
    );

                 
% Individual connector compatibility constraint
%
% EVs from group "group" may charge at a fast-charging station only when
% the available connector capacity is sufficient to meet the charging
% requirement of that EV group.

constraint
    forall(
        pot in EVPot,
        group in EVGroup,
        t in TimeSlot,
        station in FastChargingStations
    ) (
        (
            capacity_demand[group]
            - design_connector_capacity[t, station]
        )
        * assigned_evs_dest[pot, group, t, station]
        <= 0
    );     
    
                            
                 
% Slow-charging station aggregate capacity constraint
%
% For each slow-charging station, the total charging-capacity demand
% accumulated over the full planning horizon must not exceed the
% corresponding aggregate available station capacity.

constraint
    forall(
        station in SlowChargingStations
    ) (
        sum(
            t in TimeSlot,
            group in EVGroup
        ) (
            capacity_demand[group]
            * group_charging[group, t, station]
        )
        <=
        sum(t in TimeSlot) (
            design_capacity[t, station]
        )
    );                 
    
% Slow-charging station connector-capacity constraint
%
% At each time slot, the total number of EVs charging simultaneously at
% a slow-charging station must not exceed the number of available connectors.

constraint
    forall(
        t in TimeSlot,
        station in SlowChargingStations
    ) (
        sum(
            pot in EVPot,
            group in EVGroup
        ) (
            assigned_evs_dest[pot, group, t, station]
        )
        <=
        connector_num[station]
    );


                   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Total system revenue
%
% The total revenue is calculated by multiplying:
%   1. the charging price at each station and time slot,
%   2. the capacity demand of each EV group, and
%   3. the number of EVs from that group charging at the station.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

constraint
    R
    =
    sum(
        t in TimeSlot,
        station in ChargingStation,
        group in EVGroup
    ) (
        station_charging_price[t, station]/10
        * capacity_demand[group]
        * group_charging[group, t, station]
    );                                      

                                                         
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Total waiting cost (The final result should be revised by /60mins)
%
% Waiting time is the difference between:
%   1. the charging commencement time at the destination station; and
%   2. the estimated arrival time, calculated as the departure time plus
%      the driving time from the EV pot to the charging station.
%
% a_wait: monetary waiting-time coefficient per minute
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

constraint
    C_w
    =
    a_wait
    *
    (
        sum(
            pot in EVPot,
            group in EVGroup,
            t in TimeSlot,
            station in ChargingStation
        ) (
            time_mins[t]
            * assigned_evs_dest[pot, group, t, station]
        )
        -
        sum(
            pot in EVPot,
            group in EVGroup,
            t in TimeSlot,
            station in ChargingStation
        ) (
            (
                time_mins[t]
                + driving_time_mins[pot, station]
            )
            * assigned_evs_origin[pot, group, t, station]
        )
    );   
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Total driving cost
%
% The total driving cost is obtained by multiplying the driving time from
% each EV pot to the assigned charging station by the number of assigned EVs,
% and converting the resulting aggregate driving time into monetary cost.
%
% b_drive: monetary driving-time coefficient per minute
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

constraint
    C_d
    =
    b_drive
    *
    sum(
        pot in EVPot,
        group in EVGroup,
        t in TimeSlot,
        station in ChargingStation
    ) (
        driving_time_mins[pot, station]
        * assigned_evs_origin[pot, group, t, station]
    ); 
    
                                                                                                                     
                                                                                                                                                                      
var float: c_wait;
var float: c_drive;

constraint c_wait= C_w/60;
constraint c_drive = C_d/60;                                                                                            
%solve satisfy;
solve maximize R;
%solve minimize (C_d + C_w + 60*R);
%solve minimize C_w;
% minimize R;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Post-processing data

% successful charging EV at charging station
array[
    ChargingStation
] of var int: served_EVs;

constraint
  forall(s in ChargingStation)
        (served_EVs[s] = sum(pot in EVPot, group in EVGroup,t in TimeSlot,)
                            (assigned_evs_dest[pot, group, t, s]));

array[
    ChargingStation
] of var int: station_revenue;

constraint
  forall(s in ChargingStation)
        (station_revenue[s] = sum(group in EVGroup,t in TimeSlot,)
                                 (station_charging_price[t, s]/10
                                  * capacity_demand[group]
                                  * group_charging[group, t, s]));
                                  
array[
    ChargingStation
] of var float: station_waiting;                                  
                                  
constraint
  forall(s in ChargingStation)
        (station_waiting[s] = a_wait/60
    *
    (
        sum(
            pot in EVPot,
            group in EVGroup,
            t in TimeSlot,
        ) (
            time_mins[t]
            * assigned_evs_dest[pot, group, t, s]
        )
        -
        sum(
            pot in EVPot,
            group in EVGroup,
            t in TimeSlot,
        ) (
            (
                time_mins[t]
                + driving_time_mins[pot, s]
            )
            * assigned_evs_origin[pot, group, t, s]
        )
    ));  
                                       

array[
    TimeSlot
] of var int: charging_ev_time;

constraint
    forall(t in TimeSlot)
          (charging_ev_time[t] = sum(pot in EVPot,
                                     group in EVGroup,
                                     s in ChargingStation)
                                     (assigned_evs_dest[pot, group, t, s]));



output [
    "============================================================\n",
    "EV CHARGING MODEL: Optimisation results\n",
    "============================================================\n\n",

    "Revenue:\n",
    show(round(R)),
    "\n\n",

    "Waiting cost:\n",
    show(round(c_wait)),
    "\n\n",
    
    "Driving cost:\n",
    show(round(c_drive)),
    "\n\n",
    
    "Served EVs:\n",
    show(served_EVs),
    "\n\n",
    
    "Station revenue:\n",
    show(station_revenue),
    "\n\n",  

    "Charging EVs over time:\n",
    show(charging_ev_time),
    "\n\n",      
        
    "Station waiting cost:\n",
    show([round(station_waiting[s])|s in ChargingStation]),
    "\n\n",   
    ]