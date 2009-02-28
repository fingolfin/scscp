#############################################################################
#
# This is the SCSCP server configuration file.
# The service provider can start the server just by the command 
# $ gap myserver.g
#
# $Id$
#
#############################################################################

#############################################################################
#
# List of necessary packages and other commands if needed
#
#############################################################################

LogTo(); # to close log file if it was opened from .gaprc
LoadPackage("scscp");
LoadPackage("anupq");
ReadPackage("scscp/example/karatsuba.g");
LoadPackage("automata");
ReadPackage("scscp/par/automata.g");

#############################################################################
#
# Procedures and functions available for the SCSCP server
# (you will be able also to install procedures contained in other files,
# including standard GAP procedures and functions)
#
#############################################################################

FactorialAsString := x -> String(Factorial( x ) );
# Returns Factorial(x) as a string to deal also with cases when
# the result is too large to be printed

IdGroupByGenerators:=function( permlist )
# Returns the number of the group, generated by given permutations,
# in the GAP Small Groups Library.
return IdGroup( Group( permlist ) );
end;

#############################################################################
##
##  QuillenSeriesByIdGroup( [ ord, nr] )
##  
##  Let G:=SmallGroup( ord, nr ) be a p-group of order p^n. It was proved in 
##  [D.Quillen, The spectrum of an equivariant cohomology ring II, Ann. of 
##  Math., (2) 94 (1984), 573-602] that the number of conjugacy classes of 
##  maximal elementary abelian subgroups of given rank is determined by the 
##  group algebra KG. 
##  The function calculates this numbers for each possible rank and returns 
##  a list of the length n, where i-th element corresponds to the number of
##  conjugacy classes of maximal elementary abelian subgroups of the rank i.
##
QuillenSeriesByIdGroup := function( id )
local G, qs, latt, msl, ccs, ccs_repr, i, x, n;
G := SmallGroup( id );
latt := LatticeSubgroups(G);
msl := MinimalSupergroupsLattice(latt);
ccs := ConjugacyClassesSubgroups(latt);
ccs_repr := List(ccs, Representative);
qs := [];
for i in [ 1 .. LogInt( Size(G), PrimePGroup(G) ) ] do
  qs[i]:=0;
od;
for i in [ 1 .. Length(ccs_repr) ] do 
  if IsElementaryAbelian( ccs_repr[i] ) then
    if ForAll( msl[i], 
               x -> IsElementaryAbelian( ccs[x[1]][x[2]] ) = false ) then
      n := LogInt( Size(ccs_repr[i]), PrimePGroup(G) );
      qs[n] := qs[n] + 1;
    fi;
  fi;
od;
return [ id, qs ];
end;


IdGroup512ByCode:=function( code )
# The function accepts the integer number that is the code for pcgs of 
# a group of order 512 and returns the number of this group in the
# GAP Small Groups library. It is assumed that the client will make sure
# that the code is valid.
local G, F, H;
G := PcGroupCode( code, 512 );
F := PqStandardPresentation( G );H := PcGroupFpGroup( F );return IdStandardPresented512Group( H );
end;

ApplyFunction:=function( func, arg )
return EvalString( func )( arg );
end;

RingTest:=function( nrservers, nrsteps, k )
local port, proc;
# in the beginning the external client sends k=0 to the port 26133, e.g.
# NewProcess( "RingTest", [ 2, 10, 0 ], "localhost", 26133 : return_nothing );
Print(k, " \c");
k:=k+1;
if k = nrsteps then
  Print( "--> ", k," : THE LIMIT ACHIEVED, TEST STOPPED !!! \n" );
  return true;
fi;
port := 26133 + ( k mod nrservers );
Print("--> ", k," : ", port, "\n");
proc:=NewProcess( "RingTest", [ nrservers, nrsteps, k ], "localhost", port : return_nothing );
return true;
end;

LeaderElectionDone:=false;
# For example, to start on 4 servers, enter:
# nr:=4;NewProcess( "LeaderElection", ["init",0,nr], "localhost", 26133) : return_nothing );
LeaderElection:=function( status, id, nr )
local proc, nextport, m;
# status is either "init", "candidate" or "leader"
if not LeaderElectionDone then
	nextport := 26133 + ((SCSCPserverPort-26133+1) mod nr);
	if status="init" then # id can be anything on the init stage
	  	Print( "Initialising, sending candidate ", [SCSCPserverPort, IO_getpid() ], " to ", nextport, "\n" );
		proc:=NewProcess( "LeaderElection", [ "candidate", [ SCSCPserverPort, IO_getpid() ], nr ], 
	    	              "localhost", nextport : return_nothing );
		return true;
	elif status="candidate" then
		if id[2] = IO_getpid() then
			LeaderElectionDone := true;
			Print( "Got ", status, " ", id, ". Election done, sending leader ", id, " to ", nextport, "\n" );
			proc:=NewProcess( "LeaderElection", [ "leader", id, nr ], "localhost", nextport : return_nothing );
			return true; 			
		else
			if id[2] < IO_getpid() then
				m := id;
			else;
				m := [ SCSCPserverPort, IO_getpid() ];
			fi;
			Print( "Got ", status, " ", id, ", sending candidate ", m , " to ", nextport, "\n" );
			proc:=NewProcess( "LeaderElection", [ status, m, nr ], "localhost", nextport : return_nothing );
			return true; 
		fi;
	else
		LeaderElectionDone := true;
		Print( "Got ", status, " ", id, ", sending ", status, " ", id, " to ", nextport, "\n" );
		proc:=NewProcess( "LeaderElection", [ status, id, nr ], "localhost", nextport : return_nothing );
		return true; 
	fi;
else
  	Print( "Got ", status, " ", id, ", doing nothing \n" );
	return true;	
fi;	
end;

ResetLeaderElection:=function()
LeaderElectionDone:=false;
Print( "Reset LeaderElectionDone to ", LeaderElectionDone, "\n" );
return true;
end;

PointImages:=function( G, n )
local g;
return Set( List( GeneratorsOfGroup(G), g -> n^g ) );
end;

EvaluateOpenMathCode:=function( omc );
return omc;
end;

ChangeInfoLevel:=function(n)
SetInfoLevel(InfoSCSCP,n);
return true;
end;


#############################################################################
#
# Installation of procedures to make them available for WS 
# (you can also install procedures contained in other files,
# including standard GAP procedures and functions)
#
#############################################################################

# Other procedures
InstallSCSCPprocedure( "Factorial", Factorial, "See ?Factorial in GAP", 1, 1 );
InstallSCSCPprocedure( "WS_Factorial", FactorialAsString, "Returns result as a string to transmit large integers", 1 );
InstallSCSCPprocedure( "WS_Phi", Phi, "Euler's totient function", 1, 1 );
InstallSCSCPprocedure( "GroupIdentificationService", IdGroupByGenerators, 1, infinity, rec() );
InstallSCSCPprocedure( "IdGroup512ByCode", IdGroup512ByCode, 1 );
InstallSCSCPprocedure( "WS_IdGroup", IdGroup, "See ?IdGroup in GAP" );
InstallSCSCPprocedure( "QuillenSeriesByIdGroup", QuillenSeriesByIdGroup, "Quillen series of a finite p-group", 2, 2 );

# Series of factorisation methods from the GAP package FactInt
InstallSCSCPprocedure("WS_FactorsTD", FactorsTD );
InstallSCSCPprocedure("WS_FactorsPminus1", FactorsPminus1 );
InstallSCSCPprocedure("WS_FactorsPplus1", FactorsPplus1 );
InstallSCSCPprocedure("WS_FactorsECM", FactorsECM );
InstallSCSCPprocedure("WS_FactorsCFRAC", FactorsCFRAC );
InstallSCSCPprocedure("WS_FactorsMPQS", FactorsMPQS );

InstallSCSCPprocedure("WS_ConwayPolynomial", ConwayPolynomial );

KaratsubaPolynomialMultiplicationExtRepByString:=function(s1,s2)
return String( KaratsubaPolynomialMultiplicationExtRep( EvalString(s1), EvalString(s2) ) );
end;

InstallSCSCPprocedure("WS_Karatsuba", KaratsubaPolynomialMultiplicationExtRepByString);

InstallSCSCPprocedure( "ApplyFunction", ApplyFunction );

InstallSCSCPprocedure( "RingTest", RingTest );
InstallSCSCPprocedure( "LeaderElection", LeaderElection );
InstallSCSCPprocedure( "ResetLeaderElection", ResetLeaderElection );

InstallSCSCPprocedure( "ChangeInfoLevel", ChangeInfoLevel );

InstallSCSCPprocedure( "PointImages", PointImages );

InstallSCSCPprocedure( "EvaluateOpenMathCode", EvaluateOpenMathCode, 
    "Evaluates OpenMath code given as an input (without OMOBJ tags) wrapped in OMPlainString", 1, 1 );
# Example:
# EvaluateBySCSCP( "EvaluateOpenMathCode", 
#   [ OMPlainString("<OMA><OMS cd=\"arith1\" name=\"plus\"/><OMI>1</OMI><OMI>2</OMI></OMA>")],
#   "localhost",26133 ); 

#############################################################################
#
# procedures for automata
#
InstallSCSCPprocedure( "EpsilonToNFA", EpsilonToNFA ); # from the 'automata' package
InstallSCSCPprocedure( "TwoStackSerAut", TwoStackSerAut );
InstallSCSCPprocedure( "DerivedStatesOfAutomaton", DerivedStatesOfAutomaton );

#############################################################################
#
# procedures for MIP checks from the autiso package
#
if LoadPackage("autiso") = true then
	InstallSCSCPprocedure( "CheckBin512", bin -> [ bin,CheckBin(2,9, bin) ] );
fi;

#############################################################################
#
# Finally, we start the SCSCP server. Note that RunSCSCPserver will use the 
# next available port if the default port from scscp/config.g is unavailable
#
#############################################################################

ReadPackage("scscp/lib/errors.g"); # to patch ErrorInner in the server mode

#############################################################################
#
# This block is needeed if we want to do tracing
#
Print("####################################################################################\n");
Print("Setting up tracing ... \n");
IN_SCSCP_TRACING_MODE := true; # if we want to do tracing
SCSCPserverMode := true;
# some trick to guess the port number in advance
lookup := IO_gethostbyname( SCSCPserverAddress );
if lookup = fail then
  Error( "Cannot find hostname ", SCSCPserverAddress );
fi;
porttoprobe:=SCSCPserverPort-1;
repeat
	socket := IO_socket( IO.PF_INET, IO.SOCK_STREAM, "tcp" );
	IO_setsockopt( socket, IO.SOL_SOCKET,IO.SO_REUSEADDR, "xxxx" );
    porttoprobe:=porttoprobe+1;
	res := IO_bind( socket, IO_make_sockaddr_in( lookup.addr[1], porttoprobe ) );
	if res<>fail then
		SCSCPserverPort:=porttoprobe;
		IO_close( socket );
		break;
	else
		IO_close( socket );
	fi;
until false;
Print("Start logging traces to ", Concatenation( "tracing/tr", String(porttoprobe), ".txt"), "\n" );
Print("####################################################################################\n");

SCSCPLogTracesTo( Concatenation( "tr", String(porttoprobe), ".txt") );

RunSCSCPserver( SCSCPserverAddress, porttoprobe );