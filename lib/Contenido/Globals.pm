package Contenido::Globals;

# ----------------------------------------------------------------------------
# Здесь будут храниться все инициализирующие методы Contenido...
# Это НЕ объект, это просто пакет с процедурами...
# ----------------------------------------------------------------------------

use strict;
use vars qw($VERSION @ISA @EXPORT 
           $DEBUG_SQL $DEBUG_CORE $DEBUG $state $project $keeper $request $user $session $rpc_client $store_method $DB_TIME $CORE_TIME $DB_COUNT $HTML $log
           $RPC_TIME
);

use Exporter;
@ISA =      qw(Exporter);
@EXPORT =   qw($DEBUG_SQL $DEBUG_CORE $DEBUG $state $project $keeper $request $user $session $rpc_client $store_method $HTML $log);

$VERSION =  '1.0';

$state=undef;
$project=undef;
$keeper=undef;
$request=undef;
$user=undef;
$session=undef;
$rpc_client=undef;
$DEBUG=undef;
$DEBUG_SQL=undef;
$DEBUG_CORE=undef;
$store_method = undef;
$log = undef;

$DB_TIME = undef;
$DB_COUNT = undef;
$CORE_TIME = undef;
$RPC_TIME = undef;

1;
