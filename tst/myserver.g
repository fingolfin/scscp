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
LoadPackage("openmath");
LoadPackage("io");
LoadPackage("scscp");
LoadPackage("anupq");
ReadPackage("scscp/lib/errors.g"); # to patch ErrorInner in the server mode
Read("karatsuba.g");

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

IdGroup512ByCode:=function( code )
# The function accepts the integer number that is the code for pcgs of 
# a group of order 512 and returns the number of this group in the
# GAP Small Groups library. It is assumed that the client will make sure
# that the code is valid.
local G, F, H;
G := PcGroupCode( code, 512 );
F := PqStandardPresentation( G );H := PcGroupFpGroup( F );return IdStandardPresented512Group( H );
end;

#############################################################################
#
# Installation of procedures to make them available for WS 
# (you can also install procedures contained in other files,
# including standard GAP procedures and functions)
#
#############################################################################

# Store and retrieve functionality (if not permitted, remove these lines)
InstallSCSCPprocedure( "SCSCP_STORE", SCSCP_STORE );
InstallSCSCPprocedure( "SCSCP_RETRIEVE", SCSCP_RETRIEVE );
InstallSCSCPprocedure( "SCSCP_UNBIND", SCSCP_UNBIND );

# Other procedures
InstallSCSCPprocedure( "WS_factorial", FactorialAsString );
InstallSCSCPprocedure( "GroupIdentificationService", IdGroupByGenerators );
InstallSCSCPprocedure( "IdGroup512ByCode", IdGroup512ByCode );
InstallSCSCPprocedure( "WS_IdGroup", IdGroup );

# Series of factorisation methods from the GAP package FactInt
InstallSCSCPprocedure("WS_FactorsTD", FactorsTD );
InstallSCSCPprocedure("WS_FactorsPminus1", FactorsPminus1 );
InstallSCSCPprocedure("WS_FactorsPplus1", FactorsPplus1 );
InstallSCSCPprocedure("WS_FactorsECM", FactorsECM );
InstallSCSCPprocedure("WS_FactorsCFRAC", FactorsCFRAC );
InstallSCSCPprocedure("WS_FactorsMPQS", FactorsMPQS );

KaratsubaPolynomialMultiplicationExtRepByString:=function(s1,s2)
return String( KaratsubaPolynomialMultiplicationExtRep( EvalString(s1), EvalString(s2) ) );
end;

InstallSCSCPprocedure("WSKaratsuba", KaratsubaPolynomialMultiplicationExtRepByString);

#############################################################################
#
# Finally, we start the SCSCP server. Note that RunSCSCPserver will use the 
# next available port if the default port from scscp/config.g is unavailable
#
#############################################################################

RunSCSCPserver( SCSCPserverAddress, SCSCPserverPort );