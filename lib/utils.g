#############################################################################
##
#W utilities.g              The SCSCP package             Alexander Konovalov
#W                                                               Steve Linton
##
#H $Id$
##
#############################################################################

#############################################################################
#
# This function generates a random string of the length n
#
BIND_GLOBAL( "RandomString",
    function( n )
    local symbols, rs, i;
    symbols := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890";
    rs := RandomSource( IsRealRandomSource, "random" );
    return List( [1..n], i -> Random( rs, symbols) );
    end);