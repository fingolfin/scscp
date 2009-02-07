#############################################################################
##
#W parlist.g                The SCSCP package             Alexander Konovalov
#W                                                               Steve Linton
##
#H $Id: orbit.g 2299 2009-01-13 12:26:59Z alexk $
##
#############################################################################

ReadPackage("scscp/par/configpar");
SCSCPprocesses:=[];

SCSCPreset:=function()
local proc;
for proc in SCSCPprocesses do
	if not IsClosedStream( proc![1] ) then
		CloseStream( proc![1] );
	fi;	
od;
end;

ParListWithSCSCP := function( inputlist, remoteprocname )
local nrservices, status, i, itercount, recallfreq, output, callargspositions, 
      currentposition, timeout, nr, waitinglist, descriptors, s, nrdesc, result;
      
ReadPackage("scscp/par/configpar"); # reread - it may be modified between function calls
nrservices := Length( SCSCPservers );
status := [ ];

for i in [ 1 .. nrservices ] do
  if PingWebService( SCSCPservers[i][1], SCSCPservers[i][2] )=fail then
    status[i]:=0; # not alive  
    Print( SCSCPservers[i], " is not responding and will not be used!\n" );
  else  
    status[i]:=1; # alive and ready to accept
    Print( SCSCPservers[i], " responded and attached to the computation!\n" );
  fi;   
od;

output := [ ];
callargspositions := [ ];
currentposition := 0;
SCSCPprocesses:=[];
timeout:=60; # set timeout in seconds here
itercount:=0;
recallfreq:=10;

while true do
  itercount:=itercount+1;
  if IsInt(itercount/recallfreq) then
    for i in [ 1 .. nrservices ] do
      if status[i]=0 then
  	    if PingWebService( SCSCPservers[i][1], SCSCPservers[i][2] )=fail then
          Print( SCSCPservers[i], "is still not responding and can not be used!\n" );
        else  
          status[i]:=1; # alive and ready to accept
          Print( SCSCPservers[i], " responded and attached to the computation!\n" );
        fi;
      fi;
    od;    
    itercount:=0;
  fi;
  #
  # is next task available?
  #
  while currentposition < Length( inputlist ) do
    #
    # search for next available service
    #
    nr := Position( status, 1 );
    if nr<>fail then
      #
      # there is a service number 'nr' that is ready to accept procedure call
      #
      currentposition := currentposition + 1;
      # remember which argument was sent to this service
      callargspositions[nr] := currentposition;
      SCSCPprocesses[nr] := NewProcess( remoteprocname, [ inputlist[currentposition] ], 
                                   SCSCPservers[nr][1], SCSCPservers[nr][2] );
      Print("master -> ", SCSCPservers[nr], " : ", inputlist[currentposition], "\n" );
      status[nr] := 2; # status 2 means that we are waiting to hear from this service
    else
      break; # if we are here all services are busy
    fi;
  od;  
  #
  # see are there any waiting tasks
  #
  waitinglist:= Filtered( [ 1 .. nrservices ], i -> status[i]=2 );
  if Length(waitinglist)=0 then
    #
    # no next tasks and no waiting tasks - computation completed!
    #
    return output;
  fi;
  #
  # waiting until any of the running tasks will be completed
  #
  descriptors := List( SCSCPprocesses{waitinglist}, s -> IO_GetFD( s![1]![1] ) );  
  IO_select( descriptors, [ ], [ ], timeout, 0 );
  nrdesc := First( [ 1 .. Length(descriptors) ], i -> descriptors[i] <> fail );
  # if nothing came and timeout has passed then nrdesc=fail
  # This may happen when server was terminated by ^C and is in a break loop,
  # so no procedure_terminated message will appear on the client's side
  if nrdesc=fail then
   	Error( "ParSCSCP: waited for ", timeout, " seconds with no response from ", SCSCPservers{waitinglist}, "\n" );  
  else	
  	nr := waitinglist[ nrdesc ];
  	result := CompleteProcess( SCSCPprocesses[nr] );
  fi;
  if result = fail then
 	# the service SCSCPservers[nr] seems to crash, mark it as unavailable
 	if PingWebService( SCSCPservers[nr][1], SCSCPservers[nr][2] ) = fail then
 		Print( SCSCPservers[nr], " is no longer available \n" );
 	 	status[nr]:=0;
 	else
 		Error("ParSCSCP: failed to get result from ", SCSCPservers[nr] );
 	fi;
    # we need to retry the call with argument inputlist[callargspositions[nr] ]
  else
  #
  # processing the result
  #
  Print( SCSCPservers[nr], " --> master : ", result.object, "\n" );
  status[nr]:=1;
  output[ callargspositions[nr] ] := result.object;
  Unbind(callargspositions[nr]);
  fi;
od; # end of the outer loop
end;