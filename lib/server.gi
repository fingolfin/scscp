#############################################################################
##
#W server.g                 The SCSCP package             Alexander Konovalov
#W                                                               Steve Linton
##
#H $Id$
##
#############################################################################


#############################################################################
#
# RunSCSCPserver( <server>, <port> )
#
# The 1st argument is the name of the server, e.g. "localhost" or 
# "servername.somewhere.domain", the 2nd is the port number as an integer.
# The 1st argument may also be 'true' to listen to all network interfaces
# or 'false' to bind the server strictly to "localhost".
#
if VERSION <> "4.dev" then
	CALL_WITH_CATCH := CallFuncList;
fi;

InstallGlobalFunction( RunSCSCPserver,
function( server, port )

local socket, lookup, bindaddr, addr, res, disconnect, socket_descriptor, 
     stream, objrec, pos, call_id_value, atp, callinfo, output, 
     return_cookie, return_nothing, cookie, omtext, localstream, callresult, responseresult,
     errormessage, str, session_id, welcome_string, session_cookies,
     client_scscp_version, pos1, pos2, rt1, rt2, debuglevel, servername, hostname;

Append( SCSCPserviceDescription, Concatenation( " started on ", CurrentTimestamp() ) );

# additional procedures to turn tracing on/off
    
InstallSCSCPprocedure( "SCSCPStartTracing", SCSCPStartTracing, 
	"To turn on tracing mode on the server and save events to specified filename without extension", 1, 1 );
InstallSCSCPprocedure( "SCSCPStopTracing", SCSCPStopTracing, 
	"To turn off tracing mode on the server", 0, 0 );     

# forbid opportunity to send plain GAP code to the server
Unbind(OMsymRecord.cas);
     
ReadPackage("scscp/lib/errors.g"); # to patch ErrorInner in the server mode

SCSCPserverMode := true;
SCSCPserverAddress := server;
SCSCPserverPort := port;
socket := IO_socket( IO.PF_INET, IO.SOCK_STREAM, "tcp" );
IO_setsockopt( socket, IO.SOL_SOCKET,IO.SO_REUSEADDR, "xxxx" );
hostname := Hostname();

if server = true then
	bindaddr := "\000\000\000\000";
	server := "0.0.0.0";
	servername := Concatenation( hostname, ".", server );
	SCSCPserverAddress := Hostname();
else
    if server = false then
    	server := "localhost";
    	SCSCPserverAddress := "localhost";
    fi;
   	servername := server;
	lookup := IO_gethostbyname( server );
	if lookup = fail then
	    return rec( socket := fail,
	            errormsg := "RunSCSCPserver: cannot find hostname" );
	fi;
	bindaddr := lookup.addr[1];
fi;

res := IO_bind( socket, IO_make_sockaddr_in( bindaddr, port ) );
if res = fail then 
    Print( "Error: ", LastSystemError(), "\n" );
    IO_close( socket );
    # Uncomment two lines below if you want to select next 
    # available port automatically instead of quitting
    # (purely for debugging, so we did not made it an option)
    #
    # Print("Trying next port ", port+1, "\n" );
    # RunSCSCPserver( server, port+1 );
    #
    # Printing to *errout* we are able to see this even if the output was redirected
    PrintTo( "*errout*", 
      "\n******************************************\n",
      "failed to start SCSCP server at port ", port, 
      "\n******************************************\n\n" );
    # Trick to be able to quit GAP from gapscscp.sh script
    if not IsBoundGlobal( "SCSCPserverStatus" ) then
    	BindGlobal( "SCSCPserverStatus" , fail );
    fi;	
    return;
else
	welcome_string:= Concatenation( 
          "<?scscp service_name=\"GAP\" service_version=\"", VERSION, 
          "\" service_id=\"", servername, ":", String(port), ":", String(IO_getpid()), 
          "\" scscp_versions=\"1.0 1.1 1.2 1.3\" ?>");
    Print( "#I  Ready to accept TCP/IP connections at ", server, ":", port, " ... \n" );
    IO_listen( socket, 5 ); # Allow a backlog of 5 connections
    session_cookies := [];
    repeat # until false: this is the outer infinite loop
    	disconnect := false;  
    	# cleanup of cookies from previous session and resetting their list
    	for cookie in session_cookies do
    	   UnbindGlobal( cookie );
    	od;
    	session_cookies := [];
    	repeat # until disconnect: this loop is a signle SCSCP session
        	# We accept connections from everywhere
        	Info(InfoSCSCP, 1, "Waiting for new client connection at ", server, ":", port, " ..." );
        	addr := IO_MakeIPAddressPort( "0.0.0.0", 0 );
        	if IN_SCSCP_TRACING_MODE then SCSCPTraceSuspendThread(); fi;
        	socket_descriptor := IO_accept( socket, addr );
        	if IN_SCSCP_TRACING_MODE then SCSCPTraceRunThread(); fi;
        	Info(InfoSCSCP, 1, "Got connection from ", List(addr{[5..8]},INT_CHAR) );
        	stream := InputOutputTCPStream( socket_descriptor );
        	Info(InfoSCSCP, 1, "Stream created ...");
        	Info(InfoSCSCP, 1, "Sending connection initiation message" );  
        	Info(InfoSCSCP, 2, welcome_string );  
        	WriteLine( stream, welcome_string );
        	client_scscp_version := ReadLine( stream );
        	if client_scscp_version=fail then
	        	Info(InfoSCSCP, 1, "Client disconnected without sending version" );           
        		CloseStream( stream );
        		continue;
        	fi;
        	if InfoLevel(InfoSCSCP)>0 then
          		Print( "#I  Client replied with ", client_scscp_version );
        	fi;  
        	pos1 := PositionNthOccurrence(client_scscp_version,'\"',1);
        	pos2 := PositionNthOccurrence(client_scscp_version,'\"',2);
        	if pos1 = fail or pos2 = fail then
	        	Info(InfoSCSCP, 1, "Rejecting the client because of improper message ", client_scscp_version );           
        		CloseStream( stream );
        		continue;
        	else   
				client_scscp_version := client_scscp_version{[ pos1+1 .. pos2-1 ]};
        	fi;
        	if not client_scscp_version in [ "1.0", "1.1", "1.2", "1.3" ] then
				Info(InfoSCSCP, 1, "Rejecting the client because of non supported version ", 
				                   client_scscp_version );           
				WriteLine( stream, Concatenation( "<?scscp quit reason=\"non supported version ", 
				                                  client_scscp_version, "\" ?>" ) );
			else
            	SCSCP_VERSION := client_scscp_version;
            	Info(InfoSCSCP, 1, "Confirming version ", SCSCP_VERSION, " to the client ...");           
            	WriteLine( stream, Concatenation( "<?scscp version=\"", SCSCP_VERSION, "\" ?>" ) );
            	
            	# now handshaking is finished and read-evaluate-response loop is started
            	repeat
            		Info(InfoSCSCP, 1, "Waiting for OpenMath object ...");
            		# currently the timeout is 3600 seconds = 1 hour
            		if IN_SCSCP_TRACING_MODE then SCSCPTraceSuspendThread(); fi;
            		callresult:=CALL_WITH_CATCH( IO_Select, [  [ stream![1] ], [ ], [ ], [ ], 60*60, 0 ] );
            		if IN_SCSCP_TRACING_MODE then SCSCPTraceRunThread(); fi;
            		if VERSION = "4.dev" then
              			if not callresult[1] then
                			disconnect:=true;
                			break;         
              			fi;
            		fi;

            		Info(InfoSCSCP, 1, "Retrieving and evaluating ...");
            		rt1 := Runtime();
            		callresult:=CALL_WITH_CATCH( OMGetObjectWithAttributes, [ stream ] );
            		rt2 := Runtime();
            		Info(InfoSCSCP, 1, "Evaluation completed");
            
            		# FOR COMPATIBILITY WITH 4.4.12 WITH REDUCED FUNCTIONALITY
            		if VERSION <> "4.dev" then callresult := [ true, callresult ]; fi;

            		objrec := callresult[2]; # can be record, fail or list of strings

            		if objrec = fail then
              			Info(InfoSCSCP, 1, "Connection was closed by the client");
              			disconnect:=true;
              			break;
            		fi;
					# We detect the case when objrec is not fail and not record 
					# to convert it to the standard objrec format. This happens
					# when error message is returned
            		if not IsRecord(objrec) then
            			objrec := rec( object := objrec, attributes := OMParseXmlObj(OMTempVars.OMATTR) );
					fi;
                    
            		pos := PositionProperty( objrec.attributes, atp -> atp[1]="call_id" );
            		# the call_id is mandatory, however, we still can do something without it
            		if pos<>fail then 
                		call_id_value := objrec.attributes[pos][2];
            		else
                		call_id_value := "N/A";
            		fi;
            
            		if ForAny( objrec.attributes, atp -> atp[1]="option_return_cookie" ) then 
                		return_cookie := true;
            		else
                		return_cookie := false;
                		if ForAny( objrec.attributes, atp -> atp[1]="option_return_nothing" ) then 
                  			return_nothing := true;
                		else
                  			return_nothing := false;
                		fi;
            		fi;   
            		pos := PositionProperty( objrec.attributes, atp -> atp[1]="option_debuglevel" );
            		if pos<>fail then 
                		debuglevel := objrec.attributes[pos][2];
            		else
                		debuglevel := 0;
            		fi;            
            
            		# we gather in callinfo additional information about the
            		# procedure call: now it is only call_id, in the future we
            		# will add used memory, runtime, etc.
            		callinfo:= [ [ "call_id", call_id_value ] ];
            		if debuglevel > 0 then
              			Add( callinfo, [ "info_runtime", rt2-rt1 ] );
            		fi;
            		if debuglevel > 1 then
              			Add( callinfo, [ "info_memory", 1024*MemoryUsageByGAPinKbytes() ] );
            		fi;            
            		if debuglevel > 2 then
              			Add( callinfo, [ "info_message", 
                   			Concatenation( "Memory usage for the result is ", 
                   		    	           String( MemoryUsage( objrec.object ) ), " bytes" ) ] );
            		fi;
    
            		if not callresult[1] or ( IsBound( objrec.is_error) and (objrec.is_error) ) then
              			if InfoLevel( InfoSCSCP ) > 0 then
                			Print( "#I  Sending error message: ", objrec.object, "\n" );
              			fi; 
              			if objrec.object[1] = "OpenMathError: " then
                			errormessage := [ 
                  				OMPlainString( Concatenation( "<OMS cd=\"", objrec.object[4], 
                  				                              "\" name=\"", objrec.object[6], "\"/>" ) ), 
                  											  "error", objrec.object[2] ];
              			else
                			# glue together error messages into a single string
              				errormessage := [ Concatenation( servername, ":", String(port), " reports : ", 
              								  Concatenation( List( objrec.object, String ) ) ), 
              	                			  "scscp1", "error_system_specific" ];
 			  			fi;
 			  
              			if InfoLevel( InfoSCSCP ) > 2 then
                			Print("#I  Composing procedure_terminated message: \n");
                			omtext:="";
                			localstream := OutputTextString( omtext, true );
                			OMPutProcedureTerminated( localstream, 
                				rec( object:=errormessage[1], 
                				 attributes:=callinfo ), 
                				errormessage[2], 
                				errormessage[3] );
                			Print(omtext);
              			fi;          
              
              			responseresult := CALL_WITH_CATCH( OMPutProcedureTerminated, 
              										[ stream, 
              										  rec( object:=errormessage[1], 
              								   		   attributes:=callinfo ), 
              								  	      errormessage[2], 
              								  	      errormessage[3] ] );
              							  
              			# FOR COMPATIBILITY WITH 4.4.12 WITH REDUCED FUNCTIONALITY
              			if VERSION <> "4.dev" then responseresult := [ true, responseresult ]; fi;
              							  
              			if responseresult[1] then
              				Info(InfoSCSCP, 1, "procedure_terminated message sent, closing connection ...");
              			else
              				Info(InfoSCSCP, 1, "client already disconnected, closing connection on server side ...");				
              			fi;	
              			disconnect:=true;
              			break;            
            		fi;  
                       
            		Info( InfoSCSCP, 2, "call_id ", call_id_value, " : sending to client ", objrec.object ); 
            
            		if return_cookie then
                		cookie := TemporaryGlobalVarName( Concatenation( "TEMPVarSCSCP", RandomString(8) ) );  
                		ASS_GVAR( cookie, objrec.object );
                		if ISBOUND_GLOBAL( cookie ) then                                             
                    		Info( InfoSCSCP, 2, "Result stored in the global variable ", cookie );  
                		else
                    		Error( "Failed to store result in the global variable ", cookie, "\n" );                                                  
                		fi;
                		# should the cookie be destroyed after the session?
                		if SCSCP_STORE_SESSION_MODE then
                		    Add( session_cookies, cookie );
                		fi;
                		output := rec( object     := RemoteObject( cookie, hostname, port ),
                    		           attributes := callinfo );
            		elif return_nothing then
			  			output := rec( attributes:= callinfo );
            		else
              			output := rec( object := objrec.object, attributes:= callinfo );
            		fi;       
                  
            		if InfoLevel( InfoSCSCP ) > 2 then
              			Print("#I  Composing procedure_completed message: \n");
              			omtext:="";
              			localstream := OutputTextString( omtext, true );
              			CALL_WITH_CATCH( OMPutProcedureCompleted, [ localstream, output ] );
              			Print(omtext);
            		fi;       
 
            		responseresult := CALL_WITH_CATCH( OMPutProcedureCompleted, [ stream, output ] );

            		# FOR COMPATIBILITY WITH 4.4.12 WITH REDUCED FUNCTIONALITY
            		if VERSION <> "4.dev" then responseresult := [ true, responseresult ]; fi;
            						    
            		if not responseresult[1] then
              			Info(InfoSCSCP, 1, "client already disconnected, closing connection on server side ...");				
              			disconnect:=true;
              			break;   
            		fi;						    
        		until false;
        	fi;
        	Info(InfoSCSCP, 1, "Closing stream ...");
        	# socket descriptor will be closed here
        	CloseStream( stream );
    	until disconnect; # end of a single SCSCP session
    until false; # end of the outer infinite loop
    # Print("Server terminated, closing socket ... \c");   
    # IO_close(socket); # a relic from times when we had procedure to stop the server
fi;
end);
